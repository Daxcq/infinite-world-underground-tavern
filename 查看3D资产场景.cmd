@echo off
setlocal
set "TAVERN_GODOT=D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
if exist "%TAVERN_GODOT%" (
    start "" "%TAVERN_GODOT%" --path "%~dp0game" res://scenes/table_view.tscn
) else (
    echo Godot not found. Open game/scenes/table_view.tscn in Godot 4.7.2 and press F6.
    pause
)
