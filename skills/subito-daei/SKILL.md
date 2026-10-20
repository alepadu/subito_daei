---
name: subito-daei
description: Use when the user wants an audio/sound cue to play automatically on prompt submit and/or when Claude finishes responding — "play a sound when...", "notify me with audio", "beep when done", custom sound file (mp3/wav/ogg) on UserPromptSubmit or Stop hooks. Cross-platform (macOS, Linux, Windows).
---

# Sound Notification Hooks

## Overview

Wires audio cues into Claude Code hooks in `settings.json`. Personal preference → use `~/.claude/settings.json` (global), not a project file.

Cross-platform via two bundled scripts that auto-detect the right native player — never inline a single OS's command directly in the hook JSON.

Every audio file in `sounds/` is a selectable sound (list the folder at setup time, the set can grow). `sounds/descriptions.json` maps filename → short user-facing description. The user may also give any custom wav/ogg/mp3 path.

## Events the user can choose

| Choice | Hook event | Fires when |
|---|---|---|
| Command start | `UserPromptSubmit` | user sends a prompt |
| Command end | `Stop` | main Claude finishes responding (never fires for sub-agents) |
| Sub-agent start | `SubagentStart` | a sub-agent is spawned |
| Sub-agent end | `SubagentStop` | a sub-agent finishes |

Each enabled event gets its own sound. Same sound everywhere = uniform; different sounds per event = differentiated (e.g. `subito-daei.mp3` on start, `hai-rebasato.mp3` on end, and a third sound or the same one for sub-agents so they can be told apart from the main agent). **Sub-agent events are opt-in**: if the user doesn't want sub-agent sounds, simply don't wire `SubagentStart`/`SubagentStop` — main-agent sounds are unaffected.

## Steps

1. **Ask the user** (use AskUserQuestion; skip questions whose answer they already gave):
   - Which events: start / end / both (default: both).
   - Sub-agents: no sound (default) / sound on sub-agent end / sound on start and end.
   - Sound per enabled event: pick from `ls sounds/` (default: `subito-daei.mp3`), or a custom file. Show each option as its filename (without extension) as label plus its description from `sounds/descriptions.json` (`jq -r 'to_entries[]|"\(.key): \(.value)"' sounds/descriptions.json`) as the option description; a sound with no entry is shown by filename only. AskUserQuestion allows max 4 options: if more sounds exist, list them all in plain text first and offer the likeliest 4 (Other covers the rest). Offer "same sound for all" vs "different sound per event".
   If a custom file isn't audio (e.g. Audacity `.aup4` is a SQLite project container), tell them to export to wav/ogg/mp3 first.

2. **Resolve absolute paths.** Skill dir: personal-skill install `~/.claude/skills/subito-daei`; plugin install the plugin's `skills/subito-daei` directory (`${CLAUDE_PLUGIN_ROOT}` is NOT expanded in user settings.json — write the real absolute path).

3. **Detect the OS** (`uname`; assume Windows otherwise) and pick the script:
   - macOS / Linux → `scripts/play-sound.sh <absolute-file-path>` (bash). Tries `afplay` → `paplay` → `gst-launch-1.0 playbin` → `canberra-gtk-play` → `aplay`, first that succeeds wins, never fails the hook.
   - Windows → `scripts/play-sound.ps1 <absolute-file-path>` (PowerShell). `.wav` via `Media.SoundPlayer` (sync), anything else via `PresentationCore`'s `MediaPlayer` (async + bounded wait).

4. **Pipe-test each chosen sound** with the exact script invocation before writing config, e.g. `bash scripts/play-sound.sh "$SKILL_DIR/sounds/hai-rebasato.mp3"`, and confirm exit code 0 **and** that the user actually heard it (ask — exit 0 doesn't prove audible output).

   **Gotcha found in practice:** `canberra-gtk-play -f song.mp3` can fail with `Failed to play sound: File or data corrupt` even on a valid mp3, while `gst-launch-1.0 playbin uri=file:///abs/path/song.mp3` plays it fine. This is why `play-sound.sh` tries `gst-launch-1.0` before `canberra-gtk-play` — don't reorder without re-testing mp3.

5. **Read `~/.claude/settings.json` first** (Edit requires a prior Read), then merge — never replace the whole file. Re-running the setup must be idempotent: first remove any existing hook entries whose command contains `subito-daei`, then add the new ones, so changing choices (e.g. dropping sub-agent sound) removes the old hooks.

   Hook shape per enabled event (one entry per event, its own sound file):

   **macOS/Linux** (no `"shell"` field needed):
   ```json
   { "hooks": [ { "type": "command",
     "command": "bash <SKILL_DIR>/scripts/play-sound.sh <SKILL_DIR>/sounds/<sound-file> >/dev/null 2>&1 || true" } ] }
   ```

   **Windows** (needs `"shell": "powershell"` and `$env:USERPROFILE`-style absolute paths):
   ```json
   { "hooks": [ { "type": "command", "shell": "powershell",
     "command": "powershell -NoProfile -File \"<SKILL_DIR>\\scripts\\play-sound.ps1\" \"<SKILL_DIR>\\sounds\\<sound-file>\"" } ] }
   ```

   Each goes in the array under `.hooks.<EventName>`. Example jq merge (macOS/Linux) that strips old subito-daei hooks, then adds the events listed in `EVENTS` (event=sound pairs):
   ```bash
   SKILL_DIR=~/.claude/skills/subito-daei
   declare -A EVENTS=( [UserPromptSubmit]=subito-daei.mp3 [Stop]=hai-rebasato.mp3 )   # add SubagentStart/SubagentStop only if wanted
   cp ~/.claude/settings.json ~/.claude/settings.json.bak
   jq '.hooks //= {} | .hooks |= with_entries(.value |= map(select(([.hooks[]?.command] | any(contains("subito-daei"))) | not)))' ~/.claude/settings.json > /tmp/s.json
   for ev in "${!EVENTS[@]}"; do
     cmd="bash $SKILL_DIR/scripts/play-sound.sh $SKILL_DIR/sounds/${EVENTS[$ev]} >/dev/null 2>&1 || true"
     jq --arg ev "$ev" --arg cmd "$cmd" '.hooks[$ev] += [{hooks:[{type:"command",command:$cmd}]}]' /tmp/s.json > /tmp/s2.json && mv /tmp/s2.json /tmp/s.json
   done
   mv /tmp/s.json ~/.claude/settings.json
   ```
   (Use the scratchpad dir instead of `/tmp` if one is provided. Empty event arrays left after stripping are harmless.)

   Always redirect stdout/stderr and end bash commands with `|| true` — a sound cue must never block or fail the turn. `play-sound.ps1` swallows its own errors (`try`/`catch` → `exit 0`).

6. **Validate JSON + schema:**
   ```bash
   jq -e '[.hooks[][]?.hooks[]?.command | select(contains("subito-daei"))]' ~/.claude/settings.json
   ```
   Exit 0 + the expected commands (one per enabled event) = correct.

7. Tell the user it applies from the next prompt, or `/hooks` to reload immediately. To change choices later, just re-run the skill.

## Common Mistakes

- Inlining a single OS's player command directly in the hook JSON instead of calling the bundled scripts — breaks the moment the skill is used on a different machine/OS.
- Using `canberra-gtk-play` for mp3 without the `gst-launch-1.0` fallback ahead of it in the script — see gotcha above.
- Writing the hook to a project's `.claude/settings.json` for what is clearly a personal preference — use the user's own `~/.claude/settings.json`.
- Forgetting `|| true` / output redirection on the bash side, letting a missing/failed player noise up every turn.
- On Windows, forgetting `"shell": "powershell"` — without it the command runs through `cmd.exe`/bash-on-Windows semantics and `$env:USERPROFILE` won't expand.
- Trusting exit code 0 as proof of audible sound — always ask the user to confirm they heard it.
