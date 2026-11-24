# GHOSTLINE: exact plan for the next build session (M6 and M7)

Written 2026-11-13 at tag `m5`; updated at tag `m6` (version 0.6.0-m6). **Milestones 6 and 7 are done (1.0.0, tag `m7`)** apart from the items that wait on the owner (2.6 performance, 2.9 difficulty, ear-checking the music in 2.3/2.4, controller hardware in 2.8). Start at Step 0, then Step 1, then work only from the owner's reports: balance, performance and sound fixes, and the carry-over list in Step 2.10, which is now done in M8 (1.1.0) except true wall navigation for Skitters. Bump the patch version (1.0.1, ...) for each delivered fix build. This file is the task list. `docs/HANDOFF.md`
is the background (code map, traps). `docs/BUILD_BRIEF.md` is the specification.
`docs/PROGRESS.md` is the honest status of every feature.

## Where things stand (1.4.0, tag `m10`) and the next step: Milestone 11

Done since 1.0.0: M8 (1.1.0), 1.2.0 atmosphere, M9 (1.3.0: photo mode, save where you stand, Echo
ghosts), M10 (1.4.0: New Game+, wolf model, crows, papers, hazards, leaks). Still waiting on the
owner: Mac FPS for every area since 1.2.0, play notes for Acts 2 and 3, the sound, a controller.

**Milestone 11 (do in this order after Step 0; each item small, tested and committed on its own):**
1. Choir's summoned enemies: give them their own look (Echo-made bodies: the Hollow model with the
   echo_ghost or echo_dissolve shader permanently on, cyan and half-formed) instead of plain Hollows.
   Test: every Choir spawn has the new material; the Choir fight test still passes.
2. Two-way travel: a "go back" door at each area's start (Forest gate to the Dead City, Facility
   service door to the Forest) using the existing travel path (`EventBus.travel_requested`); arriving
   back restores the saved area state (already works for revisits). Test: city -> forest -> city keeps
   the city's taken pickups and Kael's weapons.
3. Shadowed lamps: a "Lamp shadows" graphics option (off on Low/Medium, on for High) that turns
   shadows on for the street lamps and the neon nearest Kael (at most 4 at once). Test: the option
   toggles `shadow_enabled` on the chosen lights and never on more than 4.
4. Performance: only once the owner sends numbers. Use docs/PERFORMANCE.md; the usual suspects are
   the mist volumes (1.2.0), the ghosts and wolves (animated rigs) and the crows. No guesses.
5. Close: PROGRESS table "M11", version 1.5.0, build, tag `m11` and `v1.5.0`, deliver the zip.

Follow the steps in order. Do not skip Step 0. Do not restart or restructure the project.
Where this file says STOP, stop and ask the owner instead of guessing.

---------------------------------------------------------------------------------------------

## Step 0. Set up and prove the project is intact (do this before any change)

1. Unzip `Ghostline-project-source-m5.zip`. The folder `ghostline/` is a git repository.
2. `cd ghostline && git tag` must list `m0 m1 m2 m3 m4 m5`. `git status` must be clean
   (if this file is the only change, that is fine).
3. Install Godot **4.7.2 stable** (standard build, not .NET) so that `godot --version` prints 4.7.2.
   Install the 4.7.2 export templates; the macOS one must be at
   `~/.local/share/godot/export_templates/4.7.2.stable/macos.zip`.
   STOP if you cannot download them: ask the owner to attach the Godot Linux binary and
   `macos.zip`. Do not switch engine version.
4. `godot --headless --path . --import` (once; errors about missing `.godot` on first run are normal).
5. `tools/run_tests.sh` and wait about 5 minutes. Required result: **262 tests, 262 passing**.
   STOP if not 262/262: report the failing test names to the owner before changing anything.
6. `tools/build_mac.sh` must end with `Exported build boots cleanly.`
7. Optional, for screenshots: `apt-get install -y xvfb mesa-vulkan-drivers`, then
   `export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json` and
   `tools/dev/run_visual_tour.sh /tmp/shots tour medium 960x540 --level=forest`
   (`--level=facility` for the Facility; no fifth argument for the Dead City).

## Rules that apply to every step

- After every task: run `tools/run_tests.sh`. Never commit with a failing test. Add tests for
  every new behaviour (GUT, in `tests/unit/` or `tests/integration/`, copy the style of
  `tests/integration/test_facility.gd`).
- Commit after each task. Every commit message ends with a `Co-Authored-By:` line for the model
  doing the work.
- Tuning numbers go in `data/` (JSON or `.tres`), never as literals in scripts.
- Update `docs/PROGRESS.md` in the same commit as the feature. Statuses are only `Working`
  (you ran it and a test covers it), `Partial`, `Placeholder`, `Not started`.
- The build machine has no GPU and no speakers. Never state a frame rate. Never say a sound
  "sounds good". Only the owner's benchmark `.txt` files and the owner's ears count.
- Do not use `queue_free` on menu children; use `UIKit.clear(container)`.
- Do not write to `GameState` from `Player.equip_weapon`. Only `Player.write_state` /
  `read_state` sync the player with the save.
- Quit only through `Game.quit_game()`.
- `export/convert_text_resources_to_binary` stays false. Export architecture stays `universal`.
- Do not add third-party assets unless the owner supplies them or they are CC0/MIT/OFL from a
  public GitHub repository; log each one in `docs/CREDITS.md`.

---------------------------------------------------------------------------------------------

## Step 1. Ask the owner for these five things (send this list as your first message, then continue with Step 2 while waiting)

1. Benchmark files from the M5 build on Medium for the Forest and the Facility (commands are in
   `docs/PERFORMANCE.md`, section "Wanted from the owner (M5)").
2. Playthrough notes for Acts 2 and 3: where he got stuck, what was too hard or too easy, both
   boss fights, anything too dark to see.
3. A decision: keep the High preset at 1600 px tall (about 46 FPS on his Mac) or lower its cap
   to 1240 px to aim for 60.
4. Whether any sound is wrong or painful on real speakers.
5. Whether he has a game controller to test with (yes or no).

How to use the answers:
- Item 3 = "lower": in `data/graphics_presets.json` set High's `max_render_height` to 1240,
  update the test that checks preset values, record it in `docs/PERFORMANCE.md` as an untested
  estimate until he sends a new High benchmark. Item 3 = "keep" or no answer: change nothing.
- Item 1: add each result as a row in the table in `docs/PERFORMANCE.md`. If Medium averages
  under 60 FPS in the Forest, do Step 2.6 first.
- Item 2: every complaint becomes a change to a value in `data/levels/forest.json`,
  `data/levels/facility.json`, `data/enemies/*.tres` or `data/story/*.json`. If no notes
  arrive, change no balance numbers.
- Item 5 = "no": leave controller features marked `Partial` and do not claim they work.

---------------------------------------------------------------------------------------------

## Note: Dead City set dressing
A dressing pass was added after `m5` (`scripts/levels/dead_city_dressing.gd`, effects in
`scripts/levels/fx/`). Ask the owner for a new Dead City Medium benchmark with it. If it costs
more than about 1 ms, lower the particle counts in `CityFX` first. The Forest and Facility
have not had the same pass; doing so is part of 2.7.

## Step 2. Milestone 6: polish and performance (brief section 18, M6)

Do these in order. Each has a "Done when" that must be true before moving on.

### 2.1 Double-tap dodge
- Where: the player's ground state and dodge entry in `scripts/player/` (find the existing
  dodge trigger with `grep -rn "dodge" scripts/player`).
- What: two presses of the same movement direction within a window start a dodge in that
  direction. Window length in `data/combat_tuning.tres` as `double_tap_window` (default 0.25).
  Add a Controls setting `double_tap_dodge` (default on) via `SettingsManager` and one row in
  `scripts/ui/settings_panel.gd`.
- Done when: tests show (a) two taps inside the window dodge, (b) two taps outside it do not,
  (c) it does nothing with the setting off. Update the M2 row in `docs/PROGRESS.md`.

### 2.2 HUD idle fade and loading screen
- HUD: in `scripts/ui/hud.gd`, fade the health/stamina/weapon group to 0 alpha after N seconds
  with no combat, damage, stamina use or weapon change; return to full at once on any of them.
  N in settings as `hud_fade_seconds` (default 6, 0 = never fade).
- Loading: in `scripts/core/game.gd`, show a black full-screen panel with the area name and
  "Loading" from the moment a boot starts until the level's `_ready` has finished and one frame
  has drawn. It must cover New Game, Load, Continue and area travel.
- Done when: tests cover fade out, fade in on damage, and the setting at 0; a test boots the
  game with a travel request and sees the loading panel removed afterwards. Change the M4 row
  "HUD fading when idle, loading screens" to its true status.

### 2.3 Adaptive music
- Generate music the same way the existing audio is made: extend
  `tools/assets/make_world_audio.py` (synthesis in Python, output into the existing audio
  folders). Make four seamless loops per area for the three areas plus the menu:
  `explore`, `tension`, `combat`, `boss` (menu needs only `explore`). Keep each loop 16 to 32
  seconds, same tempo and key within an area so layers can crossfade.
- Add `scripts/audio/music_director.gd` as an autoload. It plays through the `Music` bus and
  crossfades (1.5 s) between states chosen from signals that already exist:
  `explore` by default; `tension` while any enemy's detection meter is rising or an enemy is
  searching; `combat` while `CombatDirector` has at least one engaged enemy; `boss` between
  `EventBus.boss_started` and `EventBus.boss_ended`; silent during cinematics
  (`EventBus.cinematic_changed`).
- Stop it in `AudioManager.stop_all()` so the build check does not report leaked resources.
- Done when: unit tests drive the director with fake signals and check the chosen state for
  each case above and that `stop_all` silences it; `tools/build_mac.sh` still passes.
  Status in `docs/PROGRESS.md`: `Partial`, note "synthesized, never heard by a person" until
  the owner comments.

### 2.4 Audio mix
- Use the owner's answer to item 4 of Step 1. Without an answer do only this: make sure no
  sound plays above -3 dB on its bus, dialogue-bus subtitles' sounds are at least 6 dB above
  ambience, and ambience ducks 6 dB during cinematics. Put the levels in one file,
  `data/audio_mix.json`, read by `AudioManager`.
- Done when: a test loads `data/audio_mix.json` and checks every referenced sound exists.

### 2.5 Accessibility options
Add to Settings (one row each, bound through `UIKit` like the existing rows):
- Subtitle background on/off and three subtitle sizes (size exists; add background).
- Hold-to-press alternatives: "toggle block" (block is hold today).
- Colour-blind safe detection and telegraph colours: a setting `high_contrast_cues` that
  switches enemy telegraph and Sentinel cone colours to a second palette defined in
  `data/ui_palette.json`.
- Reduce flashing: a setting that disables lightning flashes, hit flash and flicker lights
  (`scripts/levels/weather.gd`, `CombatFX`, `scripts/levels/flicker_light.gd`).
- Camera shake already has a setting; leave it.
- Done when: each setting has a test proving the affected system reads it.

### 2.6 Performance work (only from the owner's files; no guesses)
- If the Forest Medium benchmark averages under 60 FPS or has 1% low under 45: in
  `scripts/levels/forest.gd` `_plant_trees()` the tree count is `1500 * density`; lower the
  base count in steps of 250 (move it to `data/levels/forest.json` as `tree_count` first) and
  shorten grass visibility range, then ask for a new benchmark. Record every run.
- If the Facility is under target: reduce `volumetric_fog_length` in
  `scripts/levels/facility.gd` `_build_environment()` and the range of the unshadowed point
  lights, then ask for a new benchmark.
- Shader warm-up: on the loading screen from 2.2, instance one of each enemy type, one of each
  particle effect used by `CombatFX`, the Sentinel cone and the Choir telegraph materials in
  front of the camera for two frames behind the black panel, then free them. This removes
  first-use hitches. Done when a test confirms the warm-up nodes are freed and the owner's next
  benchmark shows no frame over 100 ms after the first second.
- If no benchmark files arrive, do the shader warm-up only and leave the rest.

### 2.7 VFX pass
- Add, using Godot particles and the existing `CombatFX` autoload (no new assets):
  dust on landing and dodge, sparks on parry and on armour hits, an Echo-coloured burst when an
  enemy dies, embers for the Warden's flame, a visible collapse for the Choir when defeated
  (lights fade, pieces sink) and footstep splashes on wet surfaces in the Dead City.
- Each effect has a particle budget in `data/vfx.json` scaled by the graphics preset.
- Done when: each effect is triggered by a test (assert the node spawns and frees itself) and
  appears in a software screenshot you looked at.

### 2.8 Controller polish
- Only if the owner answered "yes" to item 5: ask him to try menus, rebinding prompts, lock-on
  and rumble, and fix what he reports. Add controller button rebinding to
  `scripts/core/input_setup.gd` next to the keyboard rebinding.
- If "no" or no answer: add controller button rebinding with tests, keep the status `Partial`
  with the note "never tried on hardware".

### 2.9 Difficulty tuning
- Only from the owner's notes (Step 1 item 2). Change values in `data/` and nowhere else.
  Record each change and its reason in a new section "Balance changes" in `docs/DESIGN.md`.

### 2.10 Carry-over items (do after 2.1 to 2.9, in this order, stop when time runs out)
1. Skitter wall crawl (`scripts/ai/enemy.gd`, data in `data/enemies/skitter.tres`).
2. Sentinels that can be disabled by a takedown from behind (they are fixed cameras in
   `scripts/ai/sentinel.gd`; add an interact prompt behind each one). Do not build a walking robot.
3. Boss intro camera moves for the Warden and a camera move on each boss phase change, using
   `Cinematic.play` with a 2 to 3 second shot.
4. One more enterable interior in the Dead City (`scripts/levels/dead_city_layout.gd`).
5. Done in M7: a "Chapters" page in the main menu that starts any of the three areas with a
   fresh Kael, unlocked by the flag `game_complete`.

### 2.11 Close Milestone 6
1. `tools/run_tests.sh` all passing. `tools/build_mac.sh` clean.
2. Set version `0.6.0-m6` in `project.godot` (`config/version`) and `0.6.0` in both version
   fields of `export_presets.cfg`. Rebuild.
3. Update `docs/PROGRESS.md` (add an "M6" table), `docs/HANDOFF.md` (test count, what is
   left), `docs/DESIGN.md`, `docs/CONTROLS.md`, `docs/PERFORMANCE.md`.
4. Commit, `git tag m6`.
5. Deliver to the owner: `build/Ghostline.zip` renamed `Ghostline-m6-mac.zip`, and a source
   zip of the whole folder excluding `build/` and `.godot/`. Report in under 300 words: what
   was added, what is still Partial, exactly what to test.

---------------------------------------------------------------------------------------------

## Step 3. Milestone 7: release (brief section 18, M7)

1. **Bug pass.** Fix everything the owner reported on M5 and M6. Then go through "Known issues"
   in `docs/PROGRESS.md` top to bottom: fix or keep, and say which for each.
   Known ones to fix: the Dead City "find fuses" objective (stage RESTORE_POWER) has no
   waypoint, so the objective marker vanishes and the owner could not find the second fuse; in
   `scripts/levels/dead_city.gd` make `_update_objective` point the marker at whichever fuse is
   still untaken (`fuse_metro` at (-3.2, -4, -40), `fuse_school` at (11.2, 0, -49.2)), with a test.
   Also: enemies path through the shut East Avenue gate (rebake or add a
   navigation obstacle while shut); tour camera stops 3 and 6 in the Forest sit inside tree
   canopies (move the two entries in `Forest.get_tour_stops`); a finished save loads into an
   empty Chamber (send it to the main menu with the Chapters page instead).
2. **Full-run test.** Add one integration test that boots each of the three areas through
   `Game` with a travel request in order, and one that completes each area's stages by calling
   the level's public methods, ending with `credits_requested`.
3. **Final build.** Version `1.0.0` in `project.godot` and `export_presets.cfg`.
   `tools/build_mac.sh` clean.
4. **Launch instructions.** Write `docs/LAUNCH.md` for a Mac user: unzip, first open with
   right-click, Open (the app is ad-hoc signed, not notarized, so Gatekeeper will warn), where
   saves and settings are stored, how to run the benchmark, how to reset settings.
5. **Docs complete.** `README.md` at the project root (what the game is, how to run, test,
   build), final `docs/PROGRESS.md`, `docs/CREDITS.md` checked against every file under
   `assets/`, a final "Known issues" list that hides nothing.
6. Commit, `git tag m7`, deliver `Ghostline-1.0-mac.zip` and the source zip, with a report
   of what is finished, what is Partial or Placeholder (the character art is still stand-in
   unless the owner supplied models), and how to launch.

---------------------------------------------------------------------------------------------

## Facts you will need (verified at tag m5)

- Run options (after `--`): `--skip-menu`, `--skip-intro`, `--show-menu`,
  `--level=dead_city|forest|facility|proving_ground`, `--benchmark`,
  `--benchmark-seconds=N`, `--benchmark-preset=low|medium|high`, `--benchmark-quit`.
- Levels: `scripts/levels/dead_city.gd`, `forest.gd`, `facility.gd`, all extend
  `scripts/levels/story_level.gd`. Scenes under `scenes/levels/<area>/`.
- Level tuning: `data/levels/<area>.json`. Story text: `data/story/<area>.json`. Documents:
  `data/documents/<area>.json` (8 each, 24 total).
- Bosses: `scripts/ai/warden_controller.gd` (phases at 60% and 25% health),
  `scripts/ai/choir.gd` with `choir_target.gd` (Choir numbers under `"choir"` in
  `data/levels/facility.json`).
- Puzzles: rules in `scripts/levels/puzzles.gd`, panels in `scripts/ui/puzzle_panels.gd`.
  Facility answers: generators 40+10, 30+20, 30+20 (capacity 50); tone order 2, 0, 3, 1.
- Saves: `GameState.SAVE_VERSION` is 3. If you add saved fields, bump it and add a migration
  in `scripts/save/save_manager.gd` with a test, as was done for 1 to 2 and 2 to 3.
- Signals between systems go through `scripts/core/event_bus.gd`. Add new ones there.
- Owner's machine: MacBook Air M4 15", 2940 x 1846. Measured so far (Dead City only): Medium
  112 FPS and 104 FPS; High at 2548 x 1600: 45.9 FPS. Nothing measured in Forest or Facility.
- All character art is placeholder (KayKit CC0). Do not claim otherwise.

## First message to paste into the new session

"Attached: Ghostline-project-source-m5.zip. Read docs/NEXT_SESSION_PLAN.md and follow it
exactly, starting at Step 0. Then read docs/HANDOFF.md. Do not restart the project. Tell me the
Step 0 results (test count, build result) before you change anything, and send me the Step 1
questions."
