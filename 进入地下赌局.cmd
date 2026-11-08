@echo off
setlocal
set "TAVERN_GODOT=D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
if exist "%TAVERN_GODOT%" (
    start "" "%TAVERN_GODOT%" --path "%~dp0game" -- --underground
) else (
    echo Godot not found. Open game/project.godot in Godot 4.7.2.
    pause
)
