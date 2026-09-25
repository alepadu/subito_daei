#!/usr/bin/env bash
# Cross-platform (macOS/Linux) sound player for Claude Code hooks.
# Tries native players in order, first that succeeds wins. Never fails the hook.
# Usage: play-sound.sh /absolute/path/to/sound-file

set -u
file="${1:-}"

[ -n "$file" ] && [ -f "$file" ] || exit 0

if command -v afplay >/dev/null 2>&1; then
    afplay "$file" >/dev/null 2>&1 && exit 0
fi
if command -v paplay >/dev/null 2>&1; then
    paplay "$file" >/dev/null 2>&1 && exit 0
fi
if command -v gst-launch-1.0 >/dev/null 2>&1; then
    gst-launch-1.0 playbin uri="file://$file" >/dev/null 2>&1 && exit 0
fi
if command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -f "$file" >/dev/null 2>&1 && exit 0
fi
if command -v aplay >/dev/null 2>&1; then
    aplay "$file" >/dev/null 2>&1 && exit 0
fi

exit 0
