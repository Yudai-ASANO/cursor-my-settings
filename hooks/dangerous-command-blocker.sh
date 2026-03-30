#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="closed"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

deny_for_match() {
    local reason="$1"
    local segment="$2"

    output_deny \
        "Blocked dangerous command: $reason" \
        "Command segment '$segment' matched blocked pattern '$reason'."
}

first_token() {
    local segment="$1"
    local trimmed="${segment#"${segment%%[![:space:]]*}"}"

    printf '%s' "${trimmed%% *}"
}

check_segment() {
    local segment="$1"
    local cmd=""

    cmd="$(first_token "$segment")"

    case "$cmd" in
        rm)
            if [[ "$segment" =~ [[:space:]]+-[[:alnum:]]*r[[:alnum:]]*f|[[:space:]]+-[[:alnum:]]*f[[:alnum:]]*r ]]; then
                deny_for_match "rm -rf/-fr" "$segment"
            fi
            ;;
        mkfs|mkfs.*)
            deny_for_match "mkfs" "$segment"
            ;;
        dd)
            if [[ "$segment" =~ if= ]]; then
                deny_for_match "dd if=" "$segment"
            fi
            ;;
        sudo|su)
            deny_for_match "$cmd" "$segment"
            ;;
        chmod)
            if [[ "$segment" =~ [[:space:]]777([[:space:]]|$) ]]; then
                deny_for_match "chmod 777" "$segment"
            fi
            ;;
        git)
            if [[ "$segment" =~ [[:space:]]reset[[:space:]]+--hard ]]; then
                deny_for_match "git reset --hard" "$segment"
            fi
            if [[ "$segment" =~ [[:space:]]clean[[:space:]]+-[[:alnum:]]*f[[:alnum:]]*d|[[:space:]]clean[[:space:]]+-[[:alnum:]]*d[[:alnum:]]*f ]]; then
                deny_for_match "git clean -fd" "$segment"
            fi
            ;;
    esac

    if [[ "$segment" =~ \>[[:space:]]*/dev/ ]]; then
        deny_for_match "> /dev/" "$segment"
    fi
}

check_remote_script_execution() {
    local command="$1"

    if [[ "$command" =~ (curl|wget)[^|]*\|[[:space:]]*(sh|bash)([[:space:]]|$) ]]; then
        output_deny \
            "Blocked dangerous command: remote script execution" \
            "Command '$command' matched blocked pattern 'curl|sh' or 'wget|sh'."
    fi
}

check_segments() {
    local remaining="$1"
    local segment=""

    while [ -n "$remaining" ]; do
        if [[ "$remaining" =~ ^([^;&|]*)(\&\&|\|\||\;|\|)(.*)$ ]]; then
            segment="${BASH_REMATCH[1]}"
            remaining="${BASH_REMATCH[3]}"
        else
            segment="$remaining"
            remaining=""
        fi

        segment="$(trim_whitespace "$segment")"
        if [ -n "$segment" ]; then
            check_segment "$segment"
        fi
    done
}

main() {
    local command=""

    read_stdin
    command="$(extract_field "$HOOK_INPUT" '.command')"
    if [ -z "$command" ]; then
        output_allow
    fi

    check_remote_script_execution "$command"
    check_segments "$command"
    output_allow
}

main "$@"
