@echo off
if not defined GODOT_BIN set "GODOT_BIN=godot"
"%GODOT_BIN%" --headless --editor --path "%~dp0" --import --quit
if errorlevel 1 exit /b 1
"%GODOT_BIN%" --path "%~dp0" res://BuyerKit/expansion/ExpansionLab.tscn
if errorlevel 1 echo Open project.godot with Godot 4.7.1, or set GODOT_BIN.
