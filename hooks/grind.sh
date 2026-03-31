#!/usr/bin/env bash
# stop hook: エージェントループ制御
# ~/.cursor/scratchpad.md に LOOP: が含まれる場合のみループを継続し、
# DONE が書き込まれるか MAX_ITERATIONS に達したら停止する。
set -euo pipefail

export HOOK_FAIL_MODE="open"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

MAX_ITERATIONS=5

stop_loop() {
    jq -nc '{}'
    exit 0
}

continue_loop() {
    local iteration="$1"
    local task="$2"

    jq -nc \
        --arg msg "[Iteration ${iteration}/${MAX_ITERATIONS}] Continue: ${task}. When finished, write DONE to ~/.cursor/scratchpad.md." \
        '{followup_message: $msg}'
    exit 0
}

main() {
    local status=""
    local loop_count=0
    local scratchpad="$HOME/.cursor/scratchpad.md"
    local task=""

    read_stdin
    status="$(extract_field "$HOOK_INPUT" '.status')"
    loop_count="$(extract_field "$HOOK_INPUT" '.loop_count')"
    loop_count="${loop_count:-0}"

    if [ "$status" != "completed" ]; then
        stop_loop
    fi

    if [ ! -f "$scratchpad" ]; then
        stop_loop
    fi

    if grep -q "DONE" "$scratchpad"; then
        stop_loop
    fi

    if ! grep -q "^LOOP:" "$scratchpad"; then
        stop_loop
    fi

    if [ "$loop_count" -ge "$MAX_ITERATIONS" ]; then
        stop_loop
    fi

    task="$(grep "^LOOP:" "$scratchpad" | head -n 1 | sed 's/^LOOP:[[:space:]]*//')"
    continue_loop "$((loop_count + 1))" "$task"
}

main "$@"
