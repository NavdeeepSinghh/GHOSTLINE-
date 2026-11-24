# GHOSTLINE: handoff for the next build session

You are continuing an in-progress game build. Read this file first, then
`docs/BUILD_BRIEF.md` (the full specification), then `docs/PROGRESS.md` (honest feature status).
Do not restart the project. All seven milestones of the brief are done (`m0` to `m7`, 1.0.0), followed by fix releases and an M8 pass (tag `m8`, 1.1.0): boss camera beats, Sentinel cable boxes, wall Skitters, Lucky's Diner, more detail everywhere.

## 1. Where things stand (2026-11-13)
- Engine: Godot 4.7.2 stable, GDScript, Forward+, Metal on macOS, Jolt physics.
- Done: pipeline, character controller and camera (M1), combat, four enemy types and stealth (M2),
  the Dead City / Act 1 (M3), menus, saves, upgrades and settings (M4), the Forest, the Facility,
  both bosses, the ending and credits (M5), polish: music, loading screens, accessibility,
  controller rebinding, effects and set dressing in all three areas (M6), and the release pass:
  chapter select, full-run tests, launch guide (M7). The game can be played from prologue to credits.
- Tests: 262 automated tests pass (`tools/run_tests.sh`, about 6 minutes).
- Owner's MacBook Air M4 15" (2940 x 1846): M1 High 33 FPS at full resolution; M2 High 84.7 FPS
  at 1720 x 1080. M3 Dead City: Medium 112 FPS (1% low 57.8), true High
  (2548 x 1600) 45.9 FPS. M4 Medium 104 FPS. Nothing measured in the Forest or Facility.
  See `docs/PERFORMANCE.md`.
- The game boots to the main menu over the Dead City. `-- --skip-menu` goes straight into play,
  `-- --level=forest` / `facility` / `proving_ground` loads that level, `-- --skip-intro` skips the
  opening cinematic. The owner played M3 and reported it fine and benchmarked M4; the M5 build
  (Acts 2 and 3) has not been run on the Mac or played by anyone.
- All character and weapon art is placeholder (KayKit CC0 low-poly models). The city is box-built.

## 2. First steps in a new session
1. Unzip the project. It is a git repository; run `git log --oneline` and `git tag`.
2. Get Godot 4.7.2 stable (standard build) and its export templates (the macOS template goes in
   `~/.local/share/godot/export_templates/4.7.2.stable/macos.zip`). If your network cannot
   download them, ask the owner to attach them. A different 4.x version may work but re-run all tests.
3. `godot --headless --path . --import` once, then `tools/run_tests.sh`. Expect 262 passing.
4. `tools/build_mac.sh` exports `build/Ghostline.zip` (universal, ad-hoc signed) and boots the
   exported package headless to catch export-only errors.
5. Screenshots without a GPU: `tools/dev/run_visual_tour.sh <out dir> [shots] [preset] [WxH]`
   (needs Xvfb and a software Vulkan driver such as lavapipe; adjust `VK_ICD_FILENAMES`).

## 3. Things that will bite you
- GUT's `wait_physics_frames(n)` advances n + 1 frames. Tests that step frame by frame run at
  about double time. Use `seconds()` or state-driven waits (`until`, `until_state`).
- `export/convert_text_resources_to_binary` must stay false. With it on, packed arrays in `.tres`
  files load empty in the exported game.
- The Mac export template only has a universal binary; keep `binary_format/architecture="universal"`.
- A freshly spawned player makes a landing noise that nearby enemies hear. In tests, spawn the
  player before placing enemies that must stay unaware.
- Hit-stop changes `Engine.time_scale`; tests disable it via `CombatFX.hitstop_enabled = false`.
- Asset sites (Kenney, Quaternius, Poly Haven, ambientCG) were blocked from the build workspace.
  Public GitHub repos (git clone, raw files), PyPI and npm worked. Log every asset in `docs/CREDITS.md`.
- The navigation map picks up the baked region a few physics frames after the level loads, and
  not always the same number. Tests that query paths must wait until a path comes back.
- Anything still playing sound when the game quits is reported as a leaked resource and fails
  `tools/build_mac.sh`. Quit through `Game.quit_game()`.
- `set_script()` on a node already in the tree does not run `_ready`. Set scripts before `add_child`.
- Interactables have no line-of-sight check: keep `Usable` radii small near thin walls.
- Screenshot tool needs `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json` after
  `apt-get install mesa-vulkan-drivers`. Dead City shots: `cine`, `play`, `ui`, `tour`.
- Menus: rebuild a page with `UIKit.clear(container)`, never bare `queue_free` on the children.
- `Player.equip_weapon` must not write to GameState (a freshly spawned Kael would overwrite a
  loaded save). `Player.write_state` / `read_state` are the only sync points.
- New Game, Load and Quit to menu reload the scene through `Game.boot_request`. Tests embed the
  game as a child, where reloading is skipped; test the pieces (`restore_state`, a boot with a
  request set) instead.
- Screenshot tool: pass `--show-menu` as the fifth argument for main menu shots; `m4` shots cover
  the pause pages and the workbench.
- Trigger zones fire when a test spawns the player inside them. Call `watch_signals` before spawning.
- Story levels extend `StoryLevel`; put shared behaviour there, not in a copy per level.
- The navmesh is baked before doors are created, so paths run through shut doors. Tests check
  the door object exists instead of expecting the path to be blocked.
- Never report a frame rate from a machine without a GPU. Only the owner's benchmark files count.

## 4. Code map
- `scripts/core/`: `game.gd` (boot, pause, respawn, benchmark), autoloads (EventBus, GameState,
  SettingsManager, InputSetup), generic `StateMachine` / `State`.
- `scripts/player/`: `player.gd` (movement helpers, stamina, combat entry points, `receive_hit`),
  `states/` (Ground, Air, Mantle, LedgeHang, Ladder, Attack, Dodge, Block, Hurt, Dead, Takedown),
  `player_visuals.gd` (animation tree, procedural crouch and climb poses, weapon model),
  `camera_rig.gd` (spring arm, lock-on).
- `scripts/combat/`: `HitInfo`, `HealthComponent`, `HitboxComponent`, `CombatFX` (autoload),
  `Ballistic` -> `Throwable`, `EchoGlob`; `HazardPuddle`; `WeaponData`; `CombatTuning`.
- `scripts/ai/`: `enemy.gd` (enum state machine), `EnemyData`, `PerceptionComponent`,
  `CombatDirector` (two attack slots), `EnemyVisuals`, `StealthZone`.
- `scripts/levels/`: `Level` base (spawn point, enemy spawns, `reset_encounters`, story hooks),
  `GrayboxBuilder`, `proving_ground.gd`; `CityBuilder`, `DeadCityLayout` (geometry),
  `dead_city.gd` (lights, interactables, enemies, story), `Weather`, `JunctionPuzzle`,
  `TriggerZone`, `flicker_light.gd`; `story_level.gd` (shared base for the three story areas),
  `forest.gd`, `facility.gd`, `puzzles.gd` (Waveform, LoadBalance, ToneLock).
- `scripts/ai/` also: `warden_controller.gd`, `choir.gd` + `choir_target.gd`, `sentinel.gd`.
- `scripts/ui/puzzle_panels.gd` draws the three puzzles in `StoryUI`.
- `scripts/story/cinematic.gd`; `scripts/ui/story_ui.gd` (objective, subtitles, hints, letterbox,
  document reader, puzzle panel, act summary); `scripts/interaction/usable.gd`;
  `scripts/audio/footsteps.gd`.
- `scripts/ui/`: `hud.gd`, `main_menu.gd`, `pause_menu.gd` (pages), `settings_panel.gd`,
  `ui_kit.gd` (builders bound to settings), `ui_style.gd`. `scripts/save/save_manager.gd`.
- `scripts/progression/`: `mission_manager.gd` (autoload), `upgrades.gd`, `documents.gd`.
- `data/`: all tuning (`player_tuning.tres`, `combat_tuning.tres`, `camera_tuning.tres`,
  `weapons/`, `enemies/`, `characters/`, `graphics_presets.json`).
- `tools/`: `run_tests.sh`, `build_mac.sh`, `assets/make_sfx.py`, `dev/` (screenshot tour).
- Physics layers: 1 world, 2 player, 3 enemies (value 4), 4 climbable (value 8), 5 interactable (value 16).

## 5. What is left, in order
Follow section 18 of `docs/BUILD_BRIEF.md`. Summary with the carry-over items:

**Carry-over from M3**
- Get the owner's Medium and High benchmarks in the Dead City and feedback from a real playthrough;
  tune `data/` and enemy placement accordingly. M3's "done" test (owner plays start to finish,
  Medium holds 60) has not been met yet.
- Skitter wall crawl. One or two more interiors. Shadows or light-blocking for interior lights.
- Listen to the synthesized audio on real speakers and fix what sounds wrong.

**Carry-over from M4**
- Owner to run the M4 build: first-launch measurement, New Game, save in a slot, quit, Continue.
- Decide High's resolution cap (stay at 1600 and 46 FPS, or about 1240 to hold 60).
- Inventory is a status page only. HUD idle fade and loading screens are not done.

**Carry-over from M5**
- Owner to play Acts 2 and 3 and benchmark the Forest and Facility (`--level=forest --benchmark`).
  Tune `data/levels/forest.json`, `facility.json` and the boss numbers from that feedback.
- Sentinels are fixed cameras; the brief describes patrolling robots that can be disabled from behind.
- Forest wildlife (deer, birds) is not built. Wolves and the Warden use stand-in models.
- Boss intro camera moves, a visible death for the Choir, and richer Facility set dressing.
- Nothing after the credits: no chapter select or New Game Plus.

**M6: polish and performance**
- Adaptive music, audio mix, VFX pass, shader warm-up, streaming hitches, accessibility options,
  controller polish (never tested on hardware), difficulty tuning, double-tap dodge.

**M7: release**
- Bug pass, final build, launch instructions, complete docs, known-issues list.

**Art (any time assets become available)**
- Replace the stand-in Kael and enemy models. Each character is described by one resource
  (`CharacterAnimationSet` for Kael, `EnemyData` for enemies), so swapping models needs no code
  changes if the new rig has equivalent clips. Ask the owner to download packs your network cannot reach.

## 6. Working rules (from the brief)
- Small and finished beats big and broken. Keep the project runnable; commit and tag each milestone.
- Tag every feature Working, Partial, Placeholder or Not started in `docs/PROGRESS.md`. Never
  claim something works unless you ran it.
- Tuning values live in `data/`, not in scripts.
- After each milestone: run tests, export, update docs, and give the owner a short report with
  what to test.
