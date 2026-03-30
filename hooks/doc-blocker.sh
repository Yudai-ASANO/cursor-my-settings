#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="closed"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

is_allowed_markdown() {
    local name="$1"

    case "$name" in
        README.md|CLAUDE.md|AGENTS.md|CONTRIBUTING.md|CHANGELOG.md|LICENSE.md)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    local path=""
    local name=""

    read_stdin
    path="$(extract_field "$HOOK_INPUT" '.tool_input.path')"
    if [ -z "$path" ]; then
        output_allow
    fi

    name="$(basename "$path")"

    case "$path" in
        *.md)
            if is_allowed_markdown "$name"; then
                output_allow
            fi
            output_deny \
                "Creating arbitrary Markdown files is blocked." \
                "Write to '$path' was blocked because only approved Markdown filenames are allowed."
            ;;
        *.txt)
            output_deny \
                "Creating .txt files is blocked." \
                "Write to '$path' was blocked because .txt outputs are not allowed."
            ;;
        *)
            output_allow
            ;;
    esac
}

main "$@"
