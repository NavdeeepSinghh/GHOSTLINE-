# Design and technical decisions

## Environment (recorded 2026-11-12)
- Build machine: cloud Linux workspace (Ubuntu 24.04, 2 vCPU Xeon, 7.8 GB RAM, **no GPU**).
  Frame rates measured here mean nothing; screenshots use software Vulkan (lavapipe) for visual review only.
- Target machine: MacBook Air M4 (macOS, arm64). No shell on it that can run a Mac app, so
  performance is validated by the in-game benchmark, run by the owner.
- Engine: **Godot 4.7.2 stable** (standard build) with matching macOS export template.
- Network: PyPI, npm and public GitHub repos (git clone, raw files) are reachable. Kenney,
  Quaternius, Poly Haven and ambientCG sites are blocked from the workspace.

## Engine choices
- Forward+ renderer, **Metal** driver on macOS (`rendering_device/driver.macos="metal"`).
- Jolt physics, 60 Hz physics tick with physics interpolation.
- 3D renders at a reduced scale and is upscaled (MetalFX Spatial on Metal, FSR 1 elsewhere); UI at native resolution.
- Godot has 1, 2 or 4 shadow cascades (no 3): Low and Medium use 2, High uses 4.
- The Mac template for 4.7.2 ships a universal binary only, so the app is universal (runs natively on arm64).
- `export/convert_text_resources_to_binary=false`: with conversion on, packed arrays in
  `.tres` data files arrived empty in the exported game (found by running the exported package).
  `tools/build_mac.sh` now boots the exported package and fails on any error.

## Architecture
- Autoloads: InputSetup, EventBus, AudioManager, SettingsManager, GameState, SaveManager, MissionManager.
- Player = CharacterBody3D + StateMachine (Ground, Air, Mantle, LedgeHang, Ladder) + components
  (LedgeDetector, InteractionSensor, PlayerVisuals). States call helpers on Player.
- All tuning lives in `data/` (`player_tuning.tres`, `camera_tuning.tres`, `characters/*.tres`, `graphics_presets.json`).
- Climbing only works on surfaces on the `climbable` physics layer, marked with yellow edges.
- A character model is described by a `CharacterAnimationSet` resource, so replacing the
  stand-in Kael means authoring one new resource, not changing code.

## Assets
- Only CC0/OFL/MIT sources reachable so far: KayKit packs on GitHub, Google Fonts repo.
- Kael currently uses the KayKit "Rogue Hooded" model as a **placeholder** (wrong proportions and style for the final look).
- Crouch, ledge hang, mantle and ladder poses are procedural (two-bone IK), because the
  stand-in pack has no climbing clips.

## Combat and AI (Milestone 2)
- Hits are `HitInfo` objects delivered to a `receive_hit()` method; `HitboxComponent` does a
  shape query each physics frame while an attack is in its active window (one hit per target per swing).
- Player combat is extra states on the same state machine (Attack, Dodge, Block, Hurt, Dead, Takedown).
- Enemies are one `Enemy` script with an enum state machine; the four types differ only in
  `data/enemies/*.tres` (`EnemyData`). `CombatDirector` hands out two attack slots.
- `PerceptionComponent` fills a 0..1 detection meter from sight and remembers noises
  (`EventBus.noise_emitted`). Visibility zones (`StealthZone`) are placed by hand.
- Hit-stop uses `Engine.time_scale` for 60 to 120 ms; tests switch it off.
- Enemies steer directly at their goal (no navmesh yet). Decision for M3: bake a navmesh for the Dead City.
- Retina fix: presets cap the 3D image height (`max_render_height`) instead of using a plain percentage.

## The Dead City (Milestone 3)
- **Built in code, not in the editor.** `DeadCityLayout` places boxes through `CityBuilder`; `dead_city.gd` owns lights, weather, interactables, enemies and story. One world-space shader (`city_surface.gdshader`) draws asphalt, concrete, facades with windows, metal and interiors, so no textures or UVs are needed and the whole static city is 12 draw calls.
- **Size.** About 130 x 200 m with a linear critical path (roof, South Street, Main Street, metro, plaza, tower) and optional loops (courtyard, pharmacy, Mara's roof, East Avenue gate). Smaller than the brief's 300 x 300 m: dense and finished over big and empty.
- **No chunk streaming.** At this size there is nothing to stream. Lights use distance fade, enemies further than 80 m sleep (`Enemy.set_asleep`), grass has a visibility range.
- **Navigation.** A `NavigationMesh` is baked from the static colliders when the level loads (streets, interiors and metro only; rooftops are excluded). Enemies ask the map for a path at most every 0.45 s and fall back to direct steering when there is no map. Doors that open (gate, shutter) are created after the bake so paths run through them.
- **Cap of 8.** `CombatDirector.engage()` refuses a ninth enemy; it keeps its alarm and joins when a place frees.
- **Weather.** `Weather` owns rain particles (camera-following volume), lightning, thunder and the 0.7 hearing multiplier, and switches to an indoor mix under roofs.
- **Story plumbing.** Levels talk to the interface only through `EventBus` (dialogue, hints, objectives, documents, fades, act completion). `StoryUI` draws them. `Cinematic` plays shot lists with timed lines and events; cinematics are code-driven rather than `AnimationPlayer` tracks because the level itself is built in code.
- **Cyan is reserved for the Echo.** It appears three times in Act 1: the growth in the metro, Lyra's subtitle colour, and the flare on the mast during transmissions.
- **Text lives in data.** `data/story/dead_city.json` (objectives, radio lines, hints, cinematic subtitles), `data/documents/dead_city.json`, `data/levels/dead_city.json` (tuning, climax wave).
- **Quitting.** `Game.quit_game()` stops all audio and waits a few frames so the mixer releases playing streams (otherwise the engine reports leaked resources at exit, which the build check treats as an error).

## Systems (Milestone 4)
- **One scene, three boots.** `Game.boot_request` (a static dictionary) tells the next load of `main.tscn` what to do: nothing (main menu), `{"mode": "new"}` or `{"mode": "load", "slot": ...}`. New Game, Load, Continue and Quit to menu all reload the scene, so every run starts from a freshly built level and no state has to be unwound by hand.
- **What a save holds.** `GameState` (version 2) carries Kael's numbers, weapons and tiers, flags, documents and `level_state`, a dictionary owned by the level. The Dead City stores its story stage, fuse count, respawn point, the keys of one-shot usables already taken, trigger zones already fired, and hints shown. Everything else (objective text, side objectives, lights, doors) is rebuilt from those on load by `DeadCity.restore_state`.
- **Checkpoint saves.** Saving is allowed at any time, but loading always places Kael at the last checkpoint. Exact-position saves would need enemy states too; not worth it for this game.
- **Mission tracker.** `MissionManager` holds the current objective, an optional waypoint, the completed list and side objectives. Levels push into it; it is not saved because it is derived from the level stage.
- **Upgrades.** `Upgrades` (static) reads tiers from `data/progression/upgrades.json`; the owned tier per weapon lives in `GameState.weapons`. `AttackState.build_hit` and the stamina spend multiply by it. Tier 3 specials are numeric keys (`finisher_bonus`, `armor_bonus`, `charge_bonus`).
- **Settings screen.** `SettingsPanel` is one control used by both menus. Every row is bound directly to a `SettingsManager` key through `UIKit`, so adding a setting is one line. A named preset always loads that preset's current values; changing any single graphics value turns the preset into Custom.
- **Rebinding.** `InputSetup.rebind` replaces an action's keyboard/mouse bindings with one chosen input and stores it under the `bindings` settings section. If another action already uses that input the two swap.
- **Auto-detect.** On the first launch the menu runs the benchmark for 10 seconds on Medium and `Game.pick_preset` applies the thresholds in `graphics_presets.json` (`_auto_detect`). High needs a large margin because it costs about 2.4 times Medium on the M4 Air.
- **Menus rebuild pages by clearing containers with `UIKit.clear`** (remove now, free later). `queue_free` alone leaves the old children in place for a frame, which renames their replacements and breaks lookups by name.

## Acts 2 and 3 (Milestone 5)
- **One base for story areas.** `StoryLevel` holds what the Dead City, Forest and Facility share: story and document data, usables keyed by name, doors, ladders, checkpoints with autosave, radio lines, hints, trigger zones, the navmesh bake and the common part of saving. Each level script is then geometry, placement and its own story stages.
- **Areas are separate scenes; travel reloads.** `EventBus.travel_requested(area)` makes `Game` write Kael's state, capture the level, set `GameState.current_area` and reload with `{"mode": "travel"}`. Each level keeps its own dictionary in `GameState.level_states` (save version 3). Travel is one way, which removes any need to keep two areas consistent.
- **The Forest is wide, the Facility is deep.** The Forest is one open strip with walls that force detours (breach, river, caves) and a daylight palette so it reads differently from the city at a glance. The Facility is four small floors stepping downward; light goes white, then emergency red, then cyan as the Echo takes over.
- **Bosses are controllers on top of existing parts.** The Warden is an ordinary `Enemy` (Bulwark data, scaled) with a `WardenController` child that swaps its `EnemyData` values per phase and adds the flame sweep. The Choir is not an `Enemy`: it is a stationary `Choir` node with strike targets (`ChoirTarget`) for the heart and pillars, and attacks that are timed areas on the platform. Both report through `EventBus.boss_*`, and both are rebuilt by `reset_encounters` when Kael dies.
- **Why the Choir's edge stops burning while the heart is open.** The heart sits at the platform's edge, outside the shrunken safe circle of phase 2. Without that rule the only moment to attack would also be a moment of unavoidable damage.
- **Puzzles are plain objects with a panel.** `Puzzles.Waveform`, `LoadBalance` and `ToneLock` hold only state and rules, so tests solve them without any interface; `PuzzlePanels` draws them. Each answer is written in a document in the same area, and a test checks the tone lock's sequence against Lyra's wall text.
- **Sentinels are cameras.** A sweeping cone with a short grace period, then an alarm that alerts nearby enemies. This keeps them readable and cheap; a walking robot would need its own model and behaviour.
- **The final blow is the player's.** When the Choir's health reaches zero the fight stops and a single prompt at the heart remains. The ending only starts when Kael uses it.
- **Epilogue.** The credits get one extra page when all 24 documents were collected.

## Milestone 6 (polish)
- **Music in layers, not tracks.** Each area's music is one loop rendered as four stems of identical length (explore, tension, combat, boss). All four start together and keep playing; `MusicDirector` only moves their volumes, in linear amplitude over 1.5 s. Changing situation never restarts the music or lands off the beat. The stems are synthesized (`tools/assets/make_music.py`) with reverb tails wrapped to the loop start, so the seam is silent.
- **State from what already exists.** The music state reads `CombatDirector.engaged_count()`, enemy AI states and the existing boss and cinematic signals. Nothing new had to report to it.
- **Loading screen first, warm-up behind it.** `Game._reload` puts the black screen up and waits two frames before reloading, so the stall of building a level shows the area name and not a frozen frame. On arrival the screen stays while every enemy type and the main effects are drawn once in front of the camera, then fades.
- **Accessibility reads one place.** `Accessibility.cue(name)` returns danger colours from `data/ui_palette.json`, and `Accessibility.reduce_flashing()` is checked by every system that flashes (lightning, hit flash, flickering lights, strobes, sparks). New flashing effects should check it too.
- **Set dressing is a separate pass per area** (`DeadCityDressing`, `ForestDressing`, `FacilityDressing`), run before the geometry is committed and the navmesh baked. Solid props stay clear of doors, ladders, pickups and trails (each pass has a keep-clear list); everything else has no collision, so routes do not change. Effects (particles, lights, wildlife) go under one child node per level so they are easy to find and count in tests.
