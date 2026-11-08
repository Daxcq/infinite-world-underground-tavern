param([string]$GodotPath)
$ErrorActionPreference = 'Stop'
$gameProject = Join-Path $PSScriptRoot 'game'
if (-not $GodotPath) {
    $gameCommand = Get-Command godot, godot4, Godot_v4.7.2-stable_mono_win64.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gameCommand) { $GodotPath = $gameCommand.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw '找不到 Godot。请在 Godot 4.7.2 中导入 game/project.godot 后按 F6/F5，或使用 -GodotPath 指定程序。'
}
& $GodotPath --path $gameProject
