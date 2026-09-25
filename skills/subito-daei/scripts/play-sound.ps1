# Cross-platform (Windows) sound player for Claude Code hooks.
# .wav uses SoundPlayer (native, synchronous). Anything else (mp3/ogg) uses
# PresentationCore's MediaPlayer, played async with a bounded wait. Never fails the hook.
# Usage: powershell -NoProfile -File play-sound.ps1 "C:\path\to\sound-file"

param(
    [Parameter(Mandatory = $true)][string]$FilePath
)

if (-not (Test-Path -LiteralPath $FilePath)) { exit 0 }

try {
    if ($FilePath -match '\.wav$') {
        (New-Object Media.SoundPlayer $FilePath).PlaySync()
    }
    else {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open([Uri]$FilePath)
        $player.Play()
        Start-Sleep -Seconds 4
        $player.Close()
    }
}
catch {
    exit 0
}
