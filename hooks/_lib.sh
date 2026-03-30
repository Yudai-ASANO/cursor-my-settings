#!/usr/bin/env bash
set -euo pipefail

export HOOK_FAIL_MODE="${HOOK_FAIL_MODE:-closed}"
# shellcheck disable=SC2034
export HOOK_INPUT=""

if ! command -v jq >/dev/null 2>&1; then
    if [ "$HOOK_FAIL_MODE" = "open" ]; then
        echo "jq is required but not installed; allowing because this hook is fail-open" >&2
        exit 0
    fi

    echo "jq is required but not installed; blocking because this hook is fail-closed" >&2
    exit 1
fi

read_stdin() {
    HOOK_INPUT="$(cat)"
}

extract_field() {
    local json="$1"
    local field="$2"

    jq -r "$field // empty" <<<"$json"
}

output_allow() {
    jq -nc '{permission:"allow"}'
    exit 0
}

output_deny() {
    local user_msg="$1"
    local agent_msg="$2"

    jq -nc \
        --arg user_msg "$user_msg" \
        --arg agent_msg "$agent_msg" \
        '{permission:"deny",user_message:$user_msg,agent_message:$agent_msg}'
    exit 2
}

output_allow_with_message() {
    local user_msg="$1"

    jq -nc --arg user_msg "$user_msg" '{permission:"allow",user_message:$user_msg}'
    exit 0
}
