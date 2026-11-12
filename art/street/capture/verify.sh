#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
godot --path . street/layout/style_slice.tscn -- --capture=res://captures/street/m2_style_slice/main.png
godot --path . street/layout/style_slice.tscn -- --no-ink --capture=res://captures/street/m2_style_slice/no_screen_lines.png
godot --path . -- --azimuth=-15 --capture=res://captures/street/final/angles/left.png
godot --path . -- --azimuth=15 --capture=res://captures/street/final/angles/right.png
godot --path . -- --benchmark=res://captures/street/final/benchmark.json
