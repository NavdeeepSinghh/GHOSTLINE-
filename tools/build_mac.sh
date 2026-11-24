#!/usr/bin/env bash
# Exports the macOS build (universal: Apple Silicon + Intel, ad-hoc signed) to
# build/Ghostline.zip, then boots the exported game package headless and
# fails if it logs any script error.
# Usage: tools/build_mac.sh      Set GODOT if Godot 4.7 is not on PATH as "godot".
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build
rm -rf build/Ghostline.zip build/_check
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "macOS" build/Ghostline.zip 2>&1 | grep -E "ERROR|WARNING" || true
[ -f build/Ghostline.zip ] || { echo "Export failed"; exit 1; }

mkdir -p build/_check
unzip -q build/Ghostline.zip -d build/_check
PCK="$(pwd)/$(find build/_check -name '*.pck' | head -1)"
LOG="$(cd build/_check && "$GODOT" --headless --main-pack "$PCK" -- --benchmark --benchmark-seconds=3 --benchmark-quit 2>&1 || true)"
rm -rf build/_check
if echo "$LOG" | grep -q -E "SCRIPT ERROR|ERROR:"; then
	echo "Exported build logs errors:"; echo "$LOG" | grep -E "ERROR" | sort | uniq -c | head -20
	exit 1
fi
echo "Exported build boots cleanly."
ls -lh build/Ghostline.zip
