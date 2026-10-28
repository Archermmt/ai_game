#!/bin/zsh
set -e
brushland_root="${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$brushland_root"
elif [[ -x /opt/homebrew/bin/godot ]]; then
  exec /opt/homebrew/bin/godot --path "$brushland_root"
else
  print "请用 Godot 4.7 stable 导入本目录的 project.godot，然后按 F6/F5 运行。"
  read "?按回车关闭窗口"
fi
