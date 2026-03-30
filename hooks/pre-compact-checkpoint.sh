#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="open"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

compact_message() {
    local message="$1"

    jq -nc --arg user_message "$message" '{user_message:$user_message}'
    exit 0
}

resolve_project_dir() {
    if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
        printf '%s' "$CURSOR_PROJECT_DIR"
        return
    fi

    extract_field "$HOOK_INPUT" '.workspace_roots[0]'
}

single_line() {
    local text="$1"

    text="${text//$'\n'/ }"
    printf '%s' "$text"
}

try_commit() {
    local project_dir="$1"
    local message="$2"

    git -C "$project_dir" commit -m "$message" 2>&1
}

try_commit_with_fallback_identity() {
    local project_dir="$1"
    local message="$2"

    git -C "$project_dir" \
        -c user.name="cursor-checkpoint" \
        -c user.email="checkpoint@localhost" \
        commit -m "$message" 2>&1
}

main() {
    local project_dir=""
    local trigger="auto"
    local status_output=""
    local commit_message=""
    local commit_output=""
    local commit_status=0
    local sha="unknown"

    read_stdin
    project_dir="$(resolve_project_dir)"
    trigger="$(extract_field "$HOOK_INPUT" '.trigger')"
    if [ -z "$trigger" ]; then
        trigger="auto"
    fi

    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        compact_message "Checkpoint skipped: project directory not found"
    fi

    if ! git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        compact_message "Checkpoint skipped: workspace is not a git repository"
    fi

    status_output="$(git -C "$project_dir" status --porcelain 2>/dev/null || true)"
    if [ -z "$status_output" ]; then
        compact_message "No changes to checkpoint"
    fi

    local had_staged=false
    if ! git -C "$project_dir" diff --cached --quiet 2>/dev/null; then
        had_staged=true
    fi

    local stash_output=""
    stash_output="$(git -C "$project_dir" stash push --include-untracked -m "cursor-checkpoint-backup" 2>&1 || true)"
    if [[ "$stash_output" != *"Saved working directory"* ]]; then
        compact_message "Checkpoint failed: unable to stash changes"
    fi

    if ! git -C "$project_dir" stash apply --index >/dev/null 2>&1; then
        git -C "$project_dir" stash apply >/dev/null 2>&1 || true
    fi

    git -C "$project_dir" add -A >/dev/null 2>&1

    commit_message="[cursor-checkpoint] auto-save before compaction ($trigger)"

    set +e
    commit_output="$(try_commit "$project_dir" "$commit_message")"
    commit_status=$?
    set -e

    if [ "$commit_status" -ne 0 ] && [[ "$commit_output" =~ (Author\ identity\ unknown|unable\ to\ auto-detect\ email\ address) ]]; then
        set +e
        commit_output="$(try_commit_with_fallback_identity "$project_dir" "$commit_message")"
        commit_status=$?
        set -e
    fi

    if [ "$commit_status" -ne 0 ]; then
        git -C "$project_dir" reset >/dev/null 2>&1 || true
        if $had_staged; then
            git -C "$project_dir" stash pop --index >/dev/null 2>&1 || git -C "$project_dir" stash pop >/dev/null 2>&1 || true
        else
            git -C "$project_dir" stash pop >/dev/null 2>&1 || true
        fi
        compact_message "Checkpoint failed: $(single_line "$commit_output")"
    fi

    git -C "$project_dir" stash drop >/dev/null 2>&1 || true

    sha="$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
    compact_message "Checkpoint: $sha created"
}

if ! main "$@"; then
    # shellcheck disable=SC2317
    compact_message "Checkpoint failed: unexpected hook error"
fi
