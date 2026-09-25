---
name: subito-daei
description: Use when the user wants an audio/sound cue to play automatically on prompt submit and/or when Claude finishes responding — "play a sound when...", "notify me with audio", "beep when done", custom sound file (mp3/wav/ogg) on UserPromptSubmit or Stop hooks. Cross-platform (macOS, Linux, Windows).
---

# Sound Notification Hooks

## Overview

Wires an audio cue into Claude Code's `UserPromptSubmit` (fires when the user sends a message) and/or `Stop` (fires when Claude finishes responding) hooks in `settings.json`. Personal preference → use `~/.claude/settings.json` (global), not a project file.

Cross-platform via two bundled scripts that auto-detect the right native player — never inline a single OS's command directly in the hook JSON. Ships with a default sound (`sounds/default.mp3`) so it works with zero configuration; the user can still point it at their own file.

## Steps

1. **Pick the sound file.** If the user doesn't name one, use the bundled default: `sounds/default.mp3` next to this skill (personal-skill install: `~/.claude/skills/subito-daei/sounds/default.mp3`; plugin install: `${CLAUDE_PLUGIN_ROOT}/skills/subito-daei/sounds/default.mp3`). If they want a custom file and it's not already an audio file (e.g. an Audacity `.aup4` project — that's a SQLite project container, not playable audio), tell them to export it to wav/ogg/mp3 from Audacity first and give you the exported path.

2. **Detect the OS** (`uname` on macOS/Linux; assume Windows otherwise) and pick the matching script:
   - macOS / Linux → `scripts/play-sound.sh <absolute-file-path>` (bash). Tries `afplay` → `paplay` → `gst-launch-1.0 playbin` → `canberra-gtk-play` → `aplay`, first that succeeds wins, never fails the hook.
   - Windows → `scripts/play-sound.ps1 <absolute-file-path>` (PowerShell). `.wav` via `Media.SoundPlayer` (sync), anything else via `PresentationCore`'s `MediaPlayer` (async + bounded wait).

3. **Pipe-test the exact script invocation before writing config**, e.g. `bash scripts/play-sound.sh ~/Music/sound.mp3`, and confirm exit code 0 **and** that the user actually heard it (ask — exit 0 doesn't prove audible output reached them; it can mean the pipeline ran but nothing came out of the speakers).

   **Gotcha found in practice:** `canberra-gtk-play -f song.mp3` can fail with `Failed to play sound: File or data corrupt` even on a valid, short mp3, while `gst-launch-1.0 playbin uri=file:///abs/path/song.mp3` plays the identical file fine. This is why `play-sound.sh` tries `gst-launch-1.0` before `canberra-gtk-play` — don't reorder that without re-testing mp3 specifically.

4. **Read `~/.claude/settings.json` first** (Edit tool requires a prior Read), then merge — don't replace the whole file. Add/merge into the `hooks` object.

   **macOS/Linux** (bash, default shell — no `"shell"` field needed):
   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/skills/subito-daei/scripts/play-sound.sh ~/.claude/skills/subito-daei/sounds/default.mp3 >/dev/null 2>&1 || true"
             }
           ]
         }
       ],
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/skills/subito-daei/scripts/play-sound.sh ~/.claude/skills/subito-daei/sounds/default.mp3 >/dev/null 2>&1 || true"
             }
           ]
         }
       ]
     }
   }
   ```

   **Windows** (needs explicit `"shell": "powershell"` and `%USERPROFILE%`-style absolute paths, since `~` doesn't expand the same way):
   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         {
           "hooks": [
             {
               "type": "command",
               "shell": "powershell",
               "command": "powershell -NoProfile -File \"$env:USERPROFILE\\.claude\\skills\\subito-daei\\scripts\\play-sound.ps1\" \"$env:USERPROFILE\\.claude\\skills\\subito-daei\\sounds\\default.mp3\""
             }
           ]
         }
       ],
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "shell": "powershell",
               "command": "powershell -NoProfile -File \"$env:USERPROFILE\\.claude\\skills\\subito-daei\\scripts\\play-sound.ps1\" \"$env:USERPROFILE\\.claude\\skills\\subito-daei\\sounds\\default.mp3\""
             }
           ]
         }
       ]
     }
   }
   ```

   Always redirect stdout/stderr and end bash commands with `|| true` — a hook that exits non-zero or prints noise pollutes the transcript/UI for no benefit; a sound cue must never block or fail the turn. `play-sound.ps1` already swallows its own errors internally (`try`/`catch` → `exit 0`), so the Windows command doesn't need a trailing `|| true` equivalent.

5. **Validate JSON + schema:**
   ```bash
   jq -e '.hooks.UserPromptSubmit[0].hooks[0].command, .hooks.Stop[0].hooks[0].command' ~/.claude/settings.json
   ```
   Exit 0 + prints the commands = correct.

6. Tell the user it applies from the next prompt, or `/hooks` to reload immediately.

## Common Mistakes

- Inlining a single OS's player command directly in the hook JSON instead of calling the bundled scripts — breaks the moment the skill is used on a different machine/OS.
- Using `canberra-gtk-play` for mp3 without the `gst-launch-1.0` fallback ahead of it in the script — see gotcha above.
- Writing the hook to a project's `.claude/settings.json` for what is clearly a personal preference — use the user's own `~/.claude/settings.json`.
- Forgetting `|| true` / output redirection on the bash side, letting a missing/failed player noise up every turn.
- On Windows, forgetting `"shell": "powershell"` — without it the command runs through `cmd.exe`/bash-on-Windows semantics and `$env:USERPROFILE` won't expand.
- Trusting exit code 0 as proof of audible sound — always ask the user to confirm they heard it.
