#!/usr/bin/env bash
# Runs the automated test suite headless. Usage: tools/run_tests.sh [extra GUT args]
# Set GODOT to your Godot 4.7 binary if it is not on PATH as "godot".
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
