#!/bin/zsh
# Put this script beside BreezelyIsles.zip's extracted .app; no Godot install needed.
set -eu
cd "$(dirname "$0")"
app_path=$(find . -maxdepth 1 -name '*.app' -type d -print -quit)
if [[ -z "$app_path" ]]; then echo '请先将 .app 解压到此脚本旁边。'; exit 1; fi
binary_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Contents/Info.plist")
mkdir -p test-results
stamp=$(date +%Y%m%d-%H%M%S)
"$app_path/Contents/MacOS/$binary_name" -- --benchmark --duration=300 --quality="${1:-medium}" > "test-results/$stamp.log" 2>&1 &
game_pid=$!
echo 'elapsed_seconds,rss_bytes' > "test-results/$stamp-memory.csv"
start=$SECONDS
while kill -0 "$game_pid" 2>/dev/null; do
 rss_kb=$(ps -o rss= -p "$game_pid" | tr -d ' ')
 if [[ -n "$rss_kb" ]]; then echo "$((SECONDS-start)),$((rss_kb*1024))" >> "test-results/$stamp-memory.csv"; fi
 sleep 2
done
wait "$game_pid"
cat "test-results/$stamp.log"
echo '请将日志、内存CSV与日志中 BENCHMARK_REPORT 指向的文件夹一起交回。'
