#!/bin/zsh
set -e
brushland_root="${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  brushland_engine=$(command -v godot)
elif [[ -x /opt/homebrew/bin/godot ]]; then
  brushland_engine=/opt/homebrew/bin/godot
else
  print "请用 Godot 4.7 stable 导入本目录的 project.godot，然后按 F5 运行。"
  read "?按回车关闭窗口"
  exit 1
fi
if [[ ! -d "$brushland_root/.godot/imported" ]]; then
  "$brushland_engine" --headless --path "$brushland_root" --editor --import
fi
exec "$brushland_engine" --path "$brushland_root"
