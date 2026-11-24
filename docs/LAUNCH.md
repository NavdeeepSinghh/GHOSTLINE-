# Playing Ghostline on a Mac

Version 1.4.1. Needs a Mac with Apple silicon or Intel, macOS 11 or later. Built and measured on a
MacBook Air M4.

## First launch
1. Unzip `Ghostline-1.4.1-mac.zip`. You get `Ghostline.app`. Move it anywhere you like
   (Applications is fine).
2. The app is signed ad hoc, not by a registered Apple developer, so macOS warns the first time.
   **Right-click (or Control-click) the app, choose Open, then Open again.** After that it opens normally.
3. If macOS instead says the app "is damaged and can't be opened", that is the same download
   warning. Run this once in Terminal, then open it normally:
   ```
   xattr -dr com.apple.quarantine "/path/to/Ghostline.app"
   ```
4. On the very first launch the game spends about ten seconds measuring performance behind the
   menu, then picks a graphics preset (Low, Medium or High). You can change it in Settings at any time.

## Where things are kept
Everything lives in `~/Library/Application Support/Ghostline/`. (Up to 1.4.0, when the game was
called The Last Echo, the folder was `TheLastEcho`; the first launch of 1.4.1 copies it across, so
saves, settings and New Game+ carry over. The old folder is left untouched and can be deleted.)
- `saves/` holds the autosave and the three manual slots (with a backup of each).
- `settings.cfg` holds graphics, audio, controls, accessibility and key bindings, and remembers
  that you have finished the game (which unlocks Chapters in the main menu).
- `benchmarks/` holds benchmark results.

To reset all settings, quit the game and delete `settings.cfg`. To start over completely, delete
the whole folder.

## Benchmark
From Terminal, in the folder that contains the app:
```
"./Ghostline.app/Contents/MacOS/Ghostline" -- --benchmark --benchmark-seconds=60 --benchmark-preset=medium --benchmark-quit
```
Add `--level=forest` or `--level=facility` to measure the other areas. Results (a summary `.txt`
and a per-frame `.csv`) are written to a `Ghostline-benchmarks` folder next to the app and to the
`benchmarks/` folder above. The pause menu also has a Benchmark button.

## Playing a particular part
Main menu > **Missions** lists every objective of all three acts; pick one to start there directly. Mission runs never write to your saves.

## Other launch options
After `--` on the command line:
- `--level=dead_city` / `forest` / `facility` jumps straight into an area (no save is touched).
- `--skip-intro` skips the opening cinematic of that area.
- `--windowed` starts in a window.
- `--preset=low|medium|high` forces a graphics preset for this run.

## If something goes wrong
- **Low frame rate:** check Settings > Graphics > Frame limit, that Low Power Mode is off, and try
  the Medium or Low preset.
- **Stuck somewhere:** Pause > Respawn at checkpoint.
- **A broken save:** the game falls back to the backup automatically; if both fail, load another
  slot or start a new game.
