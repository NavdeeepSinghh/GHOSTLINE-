#!/usr/bin/env bash
# Dev tool: renders the visual tour with software Vulkan (no GPU needed).
# Usage: tools/dev/run_visual_tour.sh <output dir> [shots] [preset] [WxH]
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:?output dir}"; SHOTS="${2:-}"; PRESET="${3:-medium}"; SIZE="${4:-1280x720}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}" GALLIVM_PERF=no_aos_sampling
ARGS=(--visual-tour="$OUT" --windowed --preset="$PRESET")
[ -n "$SHOTS" ] && ARGS+=(--shots="$SHOTS")
# Optional fifth argument: extra game options, e.g. --show-menu for the main menu shots.
[ -n "${5:-}" ] && ARGS+=("$5")
xvfb-run -a -s "-screen 0 ${SIZE}x24" godot --path . --resolution "$SIZE" --audio-driver Dummy -- "${ARGS[@]}" 2>&1 \
  | grep -v -E "^$|ALSA|snd_|audio_driver"
