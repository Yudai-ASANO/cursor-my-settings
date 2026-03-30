#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="closed"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

PROTECTED_BRANCHES="main|master"

is_force_push() {
    local command="$1"

    [[ "$command" =~ (^|[[:space:]])-f([[:space:]]|$) ]] ||
        [[ "$command" =~ --force([[:space:]]|$) ]] ||
        [[ "$command" =~ --force-with-lease ]]
}

resolve_branch_from_refspec() {
    local ref="$1"

    if [[ "$ref" == *:* ]]; then
        printf '%s' "${ref##*:}"
    else
        printf '%s' "$ref"
    fi
}

extract_push_targets() {
    local command="$1"
    local word=""
    local positional=0
    local targets=()

    for word in $command; do
        case "$word" in
            git|push) continue ;;
            -*)       continue ;;
        esac

        positional=$((positional + 1))
        if [ "$positional" -eq 1 ]; then
            continue
        fi

        targets+=("$(resolve_branch_from_refspec "$word")")
    done

    printf '%s\n' "${targets[@]}"
}

targets_protected_branch() {
    local branch="$1"

    [[ "$branch" =~ ^($PROTECTED_BRANCHES)$ ]]
}

main() {
    local command=""
    local branch=""

    read_stdin
    command="$(extract_field "$HOOK_INPUT" '.command')"
    if [ -z "$command" ]; then
        output_allow
    fi

    if ! is_force_push "$command"; then
        output_allow
    fi

    while IFS= read -r branch; do
        [ -z "$branch" ] && continue
        if targets_protected_branch "$branch"; then
            output_deny \
                "Force push to protected branch ($branch) is blocked." \
                "Command '$command' attempts to force push to '$branch'. Use a feature branch instead."
        fi
    done < <(extract_push_targets "$command")

    output_allow_with_message "Force push detected. Proceed with caution."
}

main "$@"
