# subito-daei

Claude Code plugin/skill that plays a custom sound when you send a prompt and when Claude
finishes responding. Cross-platform (macOS, Linux, Windows) — auto-detects a native audio
player, no extra dependencies to install.

## Install as a plugin

```
/plugin marketplace add alepadu/subito_daei
/plugin install subito-daei@subito-daei
```

Then just ask Claude, e.g.:

> use the subito-daei skill to play `~/Music/my-sound.mp3` on prompt submit and when you're done answering

Claude will pick the right player script for your OS, test it with you, and write the hooks
into `~/.claude/settings.json`.

## Install as a personal skill (no plugin)

```bash
git clone https://github.com/alepadu/subito_daei.git
cp -r subito_daei/skills/subito-daei ~/.claude/skills/
```

Then ask Claude to set it up the same way as above.

## What it does

- Adds a `UserPromptSubmit` hook (fires when you send a message) and/or a `Stop` hook (fires
  when Claude finishes responding) to `~/.claude/settings.json`.
- Each hook runs a small bundled script that tries native players in order until one plays
  the file, and never fails the hook if none is found:
  - **macOS/Linux** (`scripts/play-sound.sh`): `afplay` → `paplay` → `gst-launch-1.0` → `canberra-gtk-play` → `aplay`
  - **Windows** (`scripts/play-sound.ps1`): `Media.SoundPlayer` for `.wav`, `PresentationCore`'s `MediaPlayer` for anything else (mp3, ogg, ...)
- Works with any audio file — if you only have an Audacity project (`.aup4`), export it to
  wav/ogg/mp3 first.

See [`skills/subito-daei/SKILL.md`](skills/subito-daei/SKILL.md) for the full setup
walkthrough Claude follows, including the exact hook JSON for each platform.

## Why "subito-daei"

Personal sound cue project, named after the sound file it was built around. Nothing
deeper than that.
