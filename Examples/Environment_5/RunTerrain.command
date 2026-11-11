#!/bin/zsh
set -eu
project_directory="${0:A:h}"
engine="${GODOT_BIN:-}"
if [[ -z "$engine" ]] && command -v godot >/dev/null 2>&1; then engine="$(command -v godot)"; fi
if [[ -z "$engine" && -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then engine=/Applications/Godot.app/Contents/MacOS/Godot; fi
if [[ -z "$engine" || ! -x "$engine" ]]; then
  print "Open project.godot with Godot 4.5.1+, or set GODOT_BIN to your Godot executable."
  exit 1
fi
"$engine" --headless --editor --path "$project_directory" --import --quit
exec "$engine" --path "$project_directory" res://BuyerKit/TerrainLab.tscn
