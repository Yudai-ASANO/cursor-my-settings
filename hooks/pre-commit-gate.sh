#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="open"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

PRE_COMMIT_GATE_MODE="${PRE_COMMIT_GATE_MODE:-advisory}"
CHECKS_RUN=0
LAST_FAILURE=""

resolve_project_dir() {
    if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
        printf '%s' "$CURSOR_PROJECT_DIR"
        return
    fi

    extract_field "$HOOK_INPUT" '.workspace_roots[0]'
}

has_package_script() {
    local package_json="$1"
    local script_name="$2"

    jq -e --arg script_name "$script_name" '.scripts[$script_name]? != null' "$package_json" >/dev/null 2>&1
}

has_make_lint_target() {
    local makefile="$1"

    grep -Eq '^lint:' "$makefile"
}

run_check() {
    local project_dir="$1"
    local label="$2"
    shift 2
    local output=""

    CHECKS_RUN=$((CHECKS_RUN + 1))
    if output="$(cd "$project_dir" && "$@" 2>&1)"; then
        return 0
    fi

    LAST_FAILURE="$label failed"$'\n'"$output"
    return 1
}

handle_failure() {
    local summary="$1"

    if [ "$PRE_COMMIT_GATE_MODE" = "strict" ]; then
        output_deny "Pre-commit checks failed: $summary" "$LAST_FAILURE"
    fi

    output_allow_with_message "Pre-commit warning: $summary"
}

run_project_checks() {
    local project_dir="$1"
    local package_json="$project_dir/package.json"

    if [ -f "$package_json" ]; then
        if has_package_script "$package_json" "lint"; then
            run_check "$project_dir" "npm run lint" npm run lint || return 1
        fi
        if has_package_script "$package_json" "typecheck"; then
            run_check "$project_dir" "npm run typecheck" npm run typecheck || return 1
        elif has_package_script "$package_json" "type-check"; then
            run_check "$project_dir" "npm run type-check" npm run type-check || return 1
        fi
    fi

    if [ -f "$project_dir/Makefile" ] && has_make_lint_target "$project_dir/Makefile"; then
        run_check "$project_dir" "make lint" make lint || return 1
    fi

    if { [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.cfg" ]; } \
        && command -v python >/dev/null 2>&1 \
        && python -m flake8 --version >/dev/null 2>&1; then
        run_check "$project_dir" "python -m flake8" python -m flake8 || return 1
    fi
}

main() {
    local project_dir=""

    read_stdin
    project_dir="$(resolve_project_dir)"
    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        output_allow_with_message "Pre-commit checks skipped: project directory not found."
    fi

    if ! run_project_checks "$project_dir"; then
        handle_failure "review lint/typecheck output before committing."
    fi

    output_allow
}

main "$@"
