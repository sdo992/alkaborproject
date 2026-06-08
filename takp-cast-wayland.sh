#!/usr/bin/env bash
set -euo pipefail

# TAKP / EverQuest Wayland casting helper using ydotool.
#
# Based on Meriadoc's Xorg/X11 script:
#   https://github.com/kai4785/takp
#
# Usage:
#   ./takp-cast-wayland.sh <window-label> <key> <casttime> [sittime] [castspersit] [rotate]
#
# Example:
#   ./takp-cast-wayland.sh "Client1" 1 8 60 5
#
# Example meaning:
#   "Client1" - Display label only. Wayland does not reliably auto-focus windows.
#   1         - Spell key to press.
#   8         - Cast time, in seconds.
#   60        - Sit/meditate time, in seconds.
#   5         - Number of casts before sitting/meditating.
#
# Notes:
#   - This script sends key input to the currently focused window.
#   - Focus the EverQuest client manually during the countdown.
#   - Press Ctrl+C in this terminal to stop the script.

window="${1:-Client1}"
key="${2:?Missing spell key. Example: 1}"
casttime="${3:?Missing cast time in seconds. Example: 8}"
sittime="${4:-0}"
castspersit="${5:-1}"

# Preserved for compatibility with the original script.
# Rotation behavior is not currently implemented.
rotate="${6:-1}"

lockfile="${HOME}/.takp.screen.lock"

# Default to the socket path confirmed working on Bazzite Linux.
# Users may override this by setting YDOTOOL_SOCKET before running the script.
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Missing required command: $1"
        echo
        echo "Install $1 first, then try again."
        exit 1
    fi
}

check_ready() {
    require_cmd ydotool
    require_cmd flock

    if [ ! -S "$YDOTOOL_SOCKET" ]; then
        echo "ERROR: ydotool socket was not found:"
        echo "  $YDOTOOL_SOCKET"
        echo
        echo "Try:"
        echo "  sudo systemctl restart ydotool"
        echo
        echo "Then check:"
        echo "  ls -l $YDOTOOL_SOCKET"
        exit 1
    fi
}

show_startup_info() {
    echo
    echo "TAKP / EverQuest Wayland casting helper"
    echo "---------------------------------------"
    echo "Target label:       $window"
    echo "Spell key:          $key"
    echo "Cast time:          ${casttime}s"
    echo "Sit/meditate time:  ${sittime}s"
    echo "Casts before sit:   $castspersit"
    echo "Rotation setting:   $rotate"
    echo "ydotool socket:     $YDOTOOL_SOCKET"
    echo
    echo "Important:"
    echo "  This sends keys to the currently focused window."
    echo "  Focus the EverQuest client during the countdown."
    echo "  Press Ctrl+C in this terminal to stop."
    echo
}

_sleep() {
    sleep "$1"
}

countdown() {
    local seconds="${1:-7}"

    echo
    echo "Focus the ${window} window now."
    echo "Starting in ${seconds} seconds..."
    echo

    while [ "$seconds" -gt 0 ]; do
        echo "$seconds..."
        sleep 1
        seconds=$((seconds - 1))
    done

    echo "Starting."
    echo
}

key_code() {
    case "$1" in
        1) echo 2 ;;
        2) echo 3 ;;
        3) echo 4 ;;
        4) echo 5 ;;
        5) echo 6 ;;
        6) echo 7 ;;
        7) echo 8 ;;
        8) echo 9 ;;
        9) echo 10 ;;
        0) echo 11 ;;

        a|A) echo 30 ;;
        b|B) echo 48 ;;
        c|C) echo 46 ;;
        d|D) echo 32 ;;
        e|E) echo 18 ;;
        f|F) echo 33 ;;
        g|G) echo 34 ;;
        h|H) echo 35 ;;
        i|I) echo 23 ;;
        j|J) echo 36 ;;
        k|K) echo 37 ;;
        l|L) echo 38 ;;
        m|M) echo 50 ;;
        n|N) echo 49 ;;
        o|O) echo 24 ;;
        p|P) echo 25 ;;
        q|Q) echo 16 ;;
        r|R) echo 19 ;;
        s|S) echo 31 ;;
        t|T) echo 20 ;;
        u|U) echo 22 ;;
        v|V) echo 47 ;;
        w|W) echo 17 ;;
        x|X) echo 45 ;;
        y|Y) echo 21 ;;
        z|Z) echo 44 ;;

        slash|/) echo 53 ;;
        Return|return|Enter|enter) echo 28 ;;

        F1|f1) echo 59 ;;
        F2|f2) echo 60 ;;
        F3|f3) echo 61 ;;
        F4|f4) echo 62 ;;
        F5|f5) echo 63 ;;
        F6|f6) echo 64 ;;
        F7|f7) echo 65 ;;
        F8|f8) echo 66 ;;
        F9|f9) echo 67 ;;
        F10|f10) echo 68 ;;
        F11|f11) echo 87 ;;
        F12|f12) echo 88 ;;

        *)
            echo "ERROR: Unsupported key: $1"
            exit 1
            ;;
    esac
}

release_modifiers() {
    # Release common modifier keys in case one is stuck:
    # left shift, right shift, left ctrl, right ctrl,
    # left alt, right alt, left meta, right meta.
    ydotool key \
        42:0 54:0 \
        29:0 97:0 \
        56:0 100:0 \
        125:0 126:0 >/dev/null 2>&1 || true
}

tap_code() {
    local code="$1"
    ydotool key "${code}:1" "${code}:0"
}

tap_key() {
    tap_code "$(key_code "$1")"
}

tap_key_repeated() {
    local key_name="$1"
    local count="$2"
    local delay="${3:-0.16}"
    local code

    code="$(key_code "$key_name")"

    for _ in $(seq 1 "$count"); do
        tap_code "$code"
        _sleep "$delay"
    done
}

type_command_keys() {
    for k in "$@"; do
        tap_key "$k"
        _sleep 0.03
    done
}

check_ready
show_startup_info
countdown 7

while true; do
    date

    for num in $(seq 1 "$castspersit"); do
        echo "Cast [${key}] ${num}/${castspersit}"

        (
            flock 200

            release_modifiers
            _sleep 0.5

            # Original script pressed the spell key five times.
            tap_key_repeated "$key" 5 0.16

            _sleep 0.25
        ) 200>"$lockfile"

        echo "Waiting ${casttime} seconds for spell"
        _sleep "$casttime"
    done

    if [ "$sittime" -gt 0 ]; then
        (
            flock 200

            release_modifiers
            _sleep 0.5

            tap_key F1
            _sleep 0.25

            type_command_keys slash s i t Return
            _sleep 0.25
        ) 200>"$lockfile"

        echo "Medding for ${sittime} seconds"
        _sleep "$sittime"

        (
            flock 200

            release_modifiers
            _sleep 0.5

            type_command_keys slash s t a n d Return
            _sleep 0.25
        ) 200>"$lockfile"
    else
        _sleep 1
    fi
done
