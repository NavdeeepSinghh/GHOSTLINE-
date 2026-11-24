# Progress

Status tags: `Working` (run and tested), `Partial`, `Placeholder`, `Not started`.
"Tested" means the automated suite (262 tests) and/or software-rendered screenshots.
The M1 and M2 builds were launched and benchmarked on the MacBook Air M4 (High preset only). The owner played the M3 build on the Mac and reported it working (no detailed notes). The owner ran the M4 build's benchmark on the Mac (Medium, 104 FPS). **The M5 build has not been run on the Mac yet**: the Forest, the Facility, both bosses, the puzzles and the ending are verified by automated tests, path checks and software-rendered screenshots only. Nobody has played Acts 2 and 3 by hand, so their difficulty, pacing and readability are unknown. Nothing has been listened to (the build machine has no audio), so every sound is unreviewed by ear.

## M0: environment and pipeline
| Feature | Status | Notes |
|---|---|---|
| Godot 4.7.2 project, folders, autoloads | Working | |
| Git repository, milestone tags | Working | `m0` to `m5` |
| Headless test runner (`tools/run_tests.sh`, GUT 9.7.1) | Working | 262/262 passing |
| Mac export (`tools/build_mac.sh`) | Working | M1 build launched on the M4 Air (Metal) |
| Software-rendered screenshot tour | Working | `tools/dev/run_visual_tour.sh` |

## M1: character controller and camera
| Feature | Status | Notes |
|---|---|---|
| Walk / jog / sprint with stamina | Working | Speeds match tuning in tests |
| Crouch, low-ceiling check | Working | |
| Jump, coyote time, jump buffer, air control | Working | Apex height matches tuning |
| Stair and curb stepping, slopes | Working | Low-stair bug fixed 2026-11-12 |
| Vault / mantle, ledge grab, shimmy, pull up, drop, hop off | Working | Climbable surfaces only |
| Ladders (bottom and top entry, jump off) | Working | |
| Camera (spring arm, collision, shoulder offset, sprint FOV, fade near player) | Working | Feel untested on real hardware |
| Lock-on | Working | Targets enemies; moves to the next enemy when one dies |
| Keyboard/mouse input map | Working | |
| Controller input map | Partial | Bound, never tried with a physical controller |
| HUD (stamina, prompts), pause menu with settings | Working | Main menu comes in M4 |
| Graphics presets Low/Medium/High | Partial | High measured at 33 FPS on the Air; 3D resolution is now capped per preset; Medium not yet measured |
| Debug overlay (F3) and benchmark mode | Working | Writes summary + CSV |
| Save system core (slots, atomic write, backup, round-trip test) | Working | Save format version 2 with migration from version 1 |
| Kael model and animations | Placeholder | KayKit Rogue Hooded stand-in; climb poses are procedural |
| Audio | Partial | Synthesized combat sounds (music, ambience and footsteps came later; see M3 and M6) |
| Proving Ground test level | Working | Graybox only, not a game area |

## M2: combat and AI
| Feature | Status | Notes |
|---|---|---|
| Light attack, 3-hit combo with finisher | Working | Input buffered so combos chain |
| Heavy attack with hold-to-charge | Working | Breaks guards and armour |
| Dodge with invulnerable window | Working | Toward the stick, backstep with no direction; Alt, F or controller Y, or double-tap a direction (M6) |
| Block, parry, guard break | Working | Parry window 0.15 s (0.3 s on Story); mashing block cannot parry |
| Health, hit reactions, death and respawn | Working | Respawn restores the area's enemies |
| Med-injectors | Working | 3 per life, heal after 0.9 s, interrupted by hits |
| Weapons: Rebar Pipe, Fire Axe, Resonance Blade | Partial | All three usable. In the Dead City Kael starts with the pipe and finds the axe; the blade is in Dr. Vance's office in the Facility. The Proving Ground still unlocks all three. Models are primitives |
| Throwable bottles | Working | Noise at impact draws enemies; direct hit stuns |
| Hit feedback | Working | Hit-stop, shake, flash, particles, sounds, controller rumble (rumble untested on hardware) |
| Hollow (melee) | Working | |
| Skitter (fast, dash) | Partial | Feint then dash works; wall crawling is not implemented |
| Bulwark (armoured, ground slam) | Working | Armour bar, breaks to heavy attacks or the axe; slam can be jumped |
| Spitter (ranged, hazard puddle) | Working | Leads shots, backs away when approached |
| Enemy AI states | Working | Patrol, suspicious, investigate, combat, attack, search, hit, stagger, stunned |
| Group rule: two attackers at once | Working | |
| Cap of 8 enemies in a fight | Working | Enforced in code (M3); extra enemies stay alarmed at their posts until a place frees |
| Enemy navigation | Working | Path following on a baked navmesh in the Dead City (M3); direct steering where a level has none |
| Vision, hearing, detection meter | Working | Light/shadow and tall grass use hand-placed zones, not real light probing |
| Rain reducing hearing | Working | The Dead City's rain sets hearing to 70% and restores it on exit |
| Silent takedown | Working | From behind unaware enemies, or any stunned one; not on Bulwarks |
| HUD: health, injectors, weapon, enemy bars, detection | Working | |
| Enemy models | Placeholder | KayKit skeletons with cyan eyes stand in for the Hollows |
| Sentinel (facility security) | Partial | See M5: a fixed camera, not a walking robot |

## M3: the Dead City (Act 1)
| Feature | Status | Notes |
|---|---|---|
| Area layout: camp rooftop, South Street, courtyard, Main Street, metro, Tower Plaza | Working | About 130 x 200 m, smaller than the brief's 300 x 300 m. Automated tests walk the roof jump, fire-escape ladder, both metro ramps and the doorways |
| Enterable interiors | Partial | Five plus the metro (apartment, store, pharmacy, Learning Centre, tower base); the brief asks for 6 to 8 |
| Architecture and props | Partial | Box-built with one procedural shader (windows, grime, wet tops, puddles). Reads as a city in fog; not final-quality modelled art |
| Set dressing pass (2026-11-13, after M5) | Partial | `DeadCityDressing`: fire escapes, air-conditioners, drainpipes, boarded windows, posters, awnings, graffiti, about 900 pieces of litter, sagging power cables and snapped lines, four traffic signals blinking amber, rooftop tanks, antennas and two billboards, dumpsters, fire barrels, an evacuation checkpoint and ambulance in the plaza, steam from seven grates, a burning wreck, emergency lights on two cars, red beacons and smoke on the skyline, two sweeping searchlights. Almost all of it has no collision, so routes are unchanged (tests check paths and the full suite passes). Seen only in software screenshots; frame-rate cost on the Mac unknown |
| Lighting: moonlight, sodium lamps, flickering neon, volumetric fog | Working | Seen in software-rendered screenshots only; not yet seen on the Mac |
| Rain, puddle ripples, lightning and thunder | Working | Rain follows the camera and stops under roofs |
| Wet-street reflections | Partial | Puddles are in the shader and reflect in screenshots; screen-space reflection quality on Metal is unverified |
| Chunk streaming | Not started | Not needed at this size: all static geometry is 12 draw calls. Lights fade by distance and far enemies sleep instead |
| Navmesh and enemy path following | Working | Baked at load (under a second here). A test sends a Hollow round a wall and through a door |
| 20 enemies in 7 encounters, plus a 6-enemy climax wave | Working | Placement and balance are untested by hand |
| Skitter wall crawl | Not started | |
| Fuses and junction-panel puzzle | Working | Two fuses (metro, Learning Centre), then a five-relay panel; the engineer's voicemail gives the answer |
| Shortcuts | Working | East Avenue gate unlatched from the plaza side; ladder kicked down from Mara's roof |
| 8 documents with a reader | Working | 60 to 150 words each. They cannot be re-read after closing until the inventory arrives in M4 |
| Side objectives | Working | Pharmacy generator (Vital Core, +25 max health, draws two Hollows); Mara's three journal pages open her locker |
| Fire Axe found at the fire truck | Working | |
| Prologue cinematic "Static" (about 48 s) | Working | Code-driven shots, letterbox, subtitles, hold Space to skip. Kael only stands; no cinematic animation |
| Act 1 ending and summary card | Working | Oren's slip is in the ending. Summary shows time, documents, kills, takedowns, side objectives |
| Objective tracker, radio subtitles, tutorial hints | Working | Minimal versions; the full mission system is M4 |
| Checkpoints | Partial | Six, they move the respawn point and refill injectors. Nothing is written to disk until M4, so quitting loses progress |
| Footsteps per surface (concrete, wet, metal, grass, gravel) | Partial | One step per stride of ground covered, not tied to animation frames. Metal is recorded but no metal floor exists yet |
| Ambience layers (rain, indoor rain, wind, city drone, tunnel, generator) | Partial | Synthesized and wired with crossfades; never heard by a person |
| Benchmark route for the Dead City with a fixed 10-enemy fight | Working | |

## M4: systems
| Feature | Status | Notes |
|---|---|---|
| Save, quit, continue (Dead City) | Working | A test plays part of a run, saves, discards everything, loads and compares: story stage, fuses, pickups, documents, doors, ladder, weapons, upgrade tiers, cores, health, bottles, salvage, checkpoint |
| Where a load puts Kael | Partial | At the last checkpoint or workbench he reached, with all progress kept. Not at the exact spot where the save was made |
| Autosave | Working | At every checkpoint and every workbench rest |
| Three manual slots, Continue | Working | Save and Load pages in the pause menu; Load and Continue in the main menu. Continue takes the newest save |
| Main menu over the live city | Working | New Game, Continue, Load, Settings, Credits, Quit. Camera drifts along the benchmark route |
| Pause menu | Working | Resume, Objectives, Inventory, Documents, Settings, Save, Load, Load checkpoint, benchmark, Quit to menu, Quit |
| Inventory | Partial | Weapons with tier, health, stamina, injectors, bottles, salvage, cores, fuses, document count. A status page: nothing can be used or equipped from it |
| Document reader | Working | Found documents listed per area with a found count and readable again |
| Mission tracker | Partial | Current objective, completed objectives, side objectives, and an on-screen marker with distance (toggle in Settings). One mission (Act 1), rebuilt from the level's stage; not a general quest editor |
| Workbenches | Working | Two in the Dead City. Resting refills health and injectors, brings ordinary enemies back, saves, and opens upgrades |
| Weapon upgrades | Working | Three tiers per weapon bought with salvage (damage, stamina cost, a tier 3 special). Numbers in `data/progression/upgrades.json`; prices untuned by play |
| Vital Core, Lung Core | Working | Three of each across the game: one per area (+25 health, +20 stamina each) |
| Settings: graphics | Working | Preset, render scale, resolution cap, upscaler, shadows, fog, ambient occlusion, reflections, foliage, view distance, fullscreen, VSync, frame limit, show FPS |
| Settings: audio | Working | Five volume sliders, subtitles on/off, subtitle size |
| Settings: controls | Working | Sensitivity, invert Y, toggle or hold for sprint and crouch, keyboard, mouse and (M6) controller button rebinding with conflict swap |
| Settings: gameplay | Working | Difficulty (Story, Normal, Hard), objective markers, camera shake, field of view |
| First-launch auto-detect | Partial | Runs a 10-second measurement on Medium and picks Low, Medium or High. Ran end to end under software rendering; the thresholds are set from one Mac's numbers |
| HUD fading when idle, loading screens | Working | Added in M6; see below |
| Saving in the Proving Ground | Not started | Test level only |

## M5: Forest, Facility, bosses, story
| Feature | Status | Notes |
|---|---|---|
| Travel between areas | Working | Road out of the Dead City (after Act 1) to the Forest; the Forest's service tunnel to the Facility. Kael's state and each level's state carry over; autosave on arrival. One way only: no going back to an earlier area |
| Save format version 3 (per-area level states) | Working | Older saves migrate; tested |
| Forgotten Forest layout (Act 2) | Partial | About 260 x 130 m: aid post, outer wall with a breach, outpost, watchtower, river crossing, radio hut, two caves, inner gate, Warden's yard, tunnel mouth. Low-poly cone trees and box-built structures. Path checks cover the route; never walked by hand |
| Forest daylight, mist, bird ambience | Partial | Seen in software screenshots only. No deer or visible birds: the brief's wildlife is not built |
| Corrupted wolves | Working | Fast pack enemy on the shared enemy script (`data/enemies/wolf.tres`); uses the Skitter stand-in model |
| Radio waveform puzzle | Working | Match frequency and strength from the operator's log to open the inner gate |
| Forest side objectives | Working | Hunter's cache (hones the weapon in hand one tier), the lost patrol's two logs |
| The Warden (3 phases) | Partial | Armoured charges and slams; at 60% the armour falls and a flame sweep starts (pillars block it); at 25% erratic lunges with long recoveries. Phase changes, flame line-of-sight and the retry reset are tested. Uses the Bulwark stand-in model scaled up; no intro camera move; balance untested by hand |
| Oren's confession cinematic | Working | Plays after the Warden falls, then the tunnel opens |
| Underground Facility layout (Act 3) | Partial | Four levels joined by stairwells: reception and security, living quarters, research labs, Resonance Chamber. About 190 m end to end. Plain panel rooms with sparse furniture; reads as a facility, not as finished art |
| Generator load-balance puzzle | Working | Six loads across three generators of 50; restores power and opens the first stairwell |
| Research keycard, card-reader doors | Working | The card opens the Level 2 stairwell and Dr. Vance's office |
| Laser grid | Working | Burns across the lab corridor until switched off at the lab panel; the two labs give a way round |
| Sentinels | Partial | Five ceiling cameras with a sweeping cone; holding Kael in view for about a second alerts every enemy within 28 m. Two panels switch them off by floor. They cannot be destroyed, and they are cameras, not the brief's patrolling robots |
| Resonance tone lock | Working | Four tones in the order drawn on Lyra's wall (a test checks the document shows the same sequence the lock wants) |
| Resonance Blade | Working | Found in Dr. Vance's office |
| Facility side objectives | Working | Security archive, Dr. Vance's office |
| The Choir (3 phases) | Partial | Phase 1: slams and jumpable shockwaves, heart opens after each set. Phase 2: the safe platform shrinks, four enemies are called up, three pillars must be struck to open the heart. Phase 3: Lyra calls the safe side or the jump. Logic is tested by driving it directly; the fight has never been played, so timings and damage are guesses. The body is a cluster of dark shapes with lights |
| Final blow and ending | Working | After the heart stops, Kael severs the anchor himself; ending cinematic, final summary, credits, back to the main menu |
| Credits and epilogue | Working | An extra epilogue page appears when all 24 documents were found |
| 16 more documents (24 total) | Working | Eight per area, readable again from the pause menu |
| Cinematics | Partial | Seven, all code-driven camera shots with subtitles: prologue, Act 1 ending, Forest arrival, the confession, Facility arrival, the Choir's reveal, the ending. Characters only stand; no cinematic animation or voice |
| Boss health bar | Working | |
| Workbenches in the new areas | Working | Three in the Forest, two in the Facility (the second right before the Choir) |
| Replay after the ending | Working | Chapter select (M6) and New Game+ (M10) |

## M6: polish
| Feature | Status | Notes |
|---|---|---|
| Objective marker for the fuses | Working | Points at whichever fuse is still missing (reported by the owner: the marker vanished) |
| Double-tap dodge | Working | Two taps of one direction within 0.25 s (`double_tap_window` in `data/combat_tuning.tres`); on by default, Settings > Controls |
| Toggle block | Working | Optional: one press raises the guard, the next lowers it. A dodge drops it |
| Health panel fades when idle | Working | After 6 s without damage, healing, a weapon change or a fight; stays up at low health. Never/4/6/10 s in Gameplay |
| Loading screen | Working | Black screen with the area name for New Game, Load, Continue, travel and returning to the menu |
| Shader warm-up | Partial | Every enemy type and the main effects are drawn once behind the loading screen. Whether it removes hitches on the Mac is unmeasured |
| Adaptive music | Partial | Synthesized by `tools/assets/make_music.py`: a menu theme and four synced layers per area (explore, tension, combat, boss) crossfading by situation. **Nobody has listened to it**; the build machine has no speakers. Levels in `data/audio_mix.json` |
| Audio mix | Partial | Music layer levels and ambience ducking (-6 dB under cinematics) in `data/audio_mix.json`. Not tuned by ear |
| Accessibility tab | Working | Subtitles on/off, size, dark panel or outline; high-contrast danger cues (yellow/magenta instead of orange/red, `data/ui_palette.json`); reduce flashing (no lightning, hit flashes, flickering or strobing lights); camera shake; toggles for sprint, crouch, block; difficulty |
| Controller button rebinding | Partial | With swap on conflict, saved in settings. Tested in code only; no controller has been tried |
| Gameplay effects | Partial | Dust when landing hard and dodging (spray on wet ground), splashes when sprinting through water, an Echo burst when an enemy dies, embers in the Warden's flame, the Choir sinking and going dark in the ending. Counts in `data/vfx.json`, scaled by preset. Seen only in software screenshots |
| Dead City set dressing | Partial | See the 2026-11-13 dressing row in M3 |
| Forest set dressing | Partial | Firs now have three stacked tiers and colour variation; about 110 boulders, 40 fallen logs, 50 stumps, 500+ ferns and trail-edge ferns, wire along the outer wall, barrels, crates, sandbags, warning signs, a second wreck, Echo mushrooms thickening towards the facility, pollen in the clearings |
| Forest wildlife | Partial | Three flocks of birds circle overhead; three deer drink at the river and bolt when Kael comes within 14 m. Box-built; no animation beyond simple motion |
| Facility set dressing | Partial | Furniture by room (lab benches with live screens, server racks with blinking lights, lockers, cabinets, shelves, children's drawings), pipes and cable trays, hazard stripes, level signs, papers and broken glass, sparking cables, steam, rotating beacons at the stairs, Echo motes on Level 3 and in the Chamber |
| Difficulty tuning from play notes | Not started | Waits for the owner's notes |
| Performance pass from benchmarks | Not started | Waits for the owner's Forest and Facility benchmarks; nothing measured since the dressing passes |

## M7: release (1.0.0)
| Feature | Status | Notes |
|---|---|---|
| East Avenue gate in the navmesh | Working | The shut gate is baked in as a wall; opening it rebuilds the navmesh in the background. Enemies no longer path into it |
| Chapter select | Working | Finishing the game unlocks Chapters in the main menu: start any act with a fresh Kael carrying a typical loadout (`data/progression/chapters.json`). Saves are untouched |
| Full-run test | Working | One test drives the real Game node from a new game through all three areas, both hand-overs, the Choir, the ending and the credits; others boot a chapter and check the menu |
| Version 1.0.0 | Working | `project.godot`, `export_presets.cfg` |
| Launch guide | Working | `docs/LAUNCH.md`: first launch past Gatekeeper, where saves and settings live, benchmark, options, troubleshooting |
| README | Working | Project root |
| Credits audit | Working | Every file under `assets/` checked; licenses stored beside third-party files |
| Fixes from owner reports | Partial | 1.0.1: the owner could not find the two fuses (below). Other reports still welcome |

## 1.0.1: easier to find things
| Feature | Status | Notes |
|---|---|---|
| Fuses easy to spot | Working | Bigger and brighter, each with a pulsing column of orange light, a glow and sparkles that go when taken. The school fuse now sits on a crate instead of the floor. Oren's radio line says where both are. The keycard in the Facility got the same light (blue) |
| Marker on the nearer fuse | Working | Updates every second as Kael moves |
| Help when stuck | Working | Every objective in all three areas has two hints: a gentle one after 50 s on the same objective, a step-by-step one after 110 s (`data/hints.json`; texts under "stuck" in `data/story/<area>.json`). Time in cinematics and menus does not count |
| Hint key | Working | T (or D-pad down) shows the step-by-step hint at once and makes the objective marker swell for a moment. Rebindable |


## Known issues (1.0.0)
Nothing here is hidden elsewhere. In short: the game runs start to finish under test, but most of Acts 2 and 3, the music and every M6 addition have only been checked by tests and software screenshots, never by a person playing on the Mac.

- Acts 2 and 3 have never been played by a person. Expect rough balance, especially both bosses.
- No frame rate is known for the Forest or the Facility. The Forest has the most trees and grass on screen and is the likeliest to be slow.
- The Facility's upper levels are dark until the power is restored, by design; it may be too dark on a real screen.
- Travel is one way. Anything left behind in an earlier area stays there.
- Enemies called up by the Choir, and the Forest's wolves, use stand-in models from other enemy types. (Wolves have their own model since M10 / 1.4.0.)
- Loading a save returns Kael to the last checkpoint or workbench, not to where he stood when saving. (Fixed in M9 / 1.3.0 for saves made somewhere safe.)
- Performance on the M4 Air (Dead City, M3 build): Medium averages 112 FPS with one unexplained 4-second dip to about 90 FPS (1% low 57.8). High at its real resolution averages 46 FPS and does not hold 60.
- Point lights have no shadows (only the moon and four lamps do), so neon and lamp light shows through thin walls.
- The stand-in characters are chunky low-poly models; they do not match the art direction.
- The music has never been heard by a person; levels and balance between layers are guesses.
- All the set dressing adds draw work; nothing has been measured on the Mac since it went in.
- Controller support has never been tried on hardware. Menus are built from standard focusable controls but were only driven by mouse and by tests.
- No sound has been reviewed by ear from the build side.

## 1.0.2: mission select
| Feature | Status | Notes |
|---|---|---|
| Missions page | Working | Main menu > Missions, available from the start: 16 missions (8 in the Dead City, 4 in the Forest, 4 in the Facility) start directly at that objective, with Kael at its checkpoint and a fitting loadout. Defined in `data/progression/missions.json`; a test boots every one and checks the area, objective and that Kael stands on the ground there |
| Practice runs never save | Working | Missions and Chapters turn off autosave and manual saving (also after travelling on to the next area), so the player's own saves are never overwritten. Before this, Chapters did autosave |

## M8 (1.1.0): after the brief
The seven milestones of the brief were done at 1.0.0; this pass takes the post-release list plus an owner request for more detail.

| Feature | Status | Notes |
|---|---|---|
| Warden entrance | Working | First time in the yard: a short camera move as the Warden rises, then a title card. The Warden holds still while it plays; it does not replay after a death |
| Boss phase beats | Working | A 2-second camera swing on every phase change of the Warden and the Choir. The boss (and the Choir's summoned enemies) freeze for it, so nothing hits Kael off-screen; boss music keeps playing through it. The ending and Oren's confession take over if a beat is still running |
| Boss title cards | Working | THE WARDEN, THE CHOIR |
| Sentinel cable boxes | Working | A yellow junction box on the wall under each camera: sneak underneath and press E to put that one camera out. Refused while it is watching Kael. Saved |
| Sentinel headings | Working | Three of the five cameras faced the wall they hang on; fixed, with a test that every camera looks into open space |
| Skitters on walls | Partial | Five Skitters (3 Dead City, 2 Facility) cling head-down to walls, crawling side to side, and leap down when they see Kael within 11 m, hear a noise or are hit. They do not climb walls during a fight or path along walls; that would need wall navigation |
| Lucky's Diner | Working | New interior on East Avenue: booths with breakfast still on the tables, counter and stools, kitchen behind the pass, a lit jukebox, two salvage pickups and a bottle crate. Neon sign outside |
| Dead City detail | Partial | About 25 shopfronts with roll-down shutters (some jammed half open) and painted shop signs, balconies with railings and plants, washing strung across the West Alley, benches, hydrants, mailboxes, bollards, chained bikes, cones, shopping carts, planters, dead street trees in iron grates, potholes and cracks |
| Forest detail | Partial | Broadleaf trees and birches mixed into the firs (about 18%), wildflower drifts at clearing edges, old fence lines with sagging wire, a hidden abandoned camp north of the watchtower |
| Facility detail | Partial | EXIT signs over every stairwell door, fire extinguishers, stopped clocks, notice boards with pinned notes, ceiling light frames, missing ceiling tiles with wires hanging through, a water cooler, equipment trolleys |

All of the above is seen only in software screenshots; the frame-rate cost of the extra detail on the Mac is unmeasured.

## 1.2.0: atmosphere
Owner request: "add more details and make it more cool".

| Feature | Status | Notes |
|---|---|---|
| Film look | Working | Vignette, light film grain and slight colour fringing over the 3D view (not over the HUD). A red edge flashes when Kael is hit and beats slowly below 30% health; softer with Reduce flashing. Settings > Graphics > Film look turns it all off. Tested |
| Colour grading | Partial | Dead City colder and harder (more contrast, less saturation), Forest warmer and greener, Facility cold and flat. Screenshot only |
| Rain splashes | Working | Drops burst on the ground around Kael in Dead City; none under cover. Tested |
| Holographic ads | Partial | Three glitching hologram billboards in Dead City (Main Street, South Street, East Avenue) and two in the Facility (lobby, labs). They glitch every few seconds; never with Reduce flashing |
| The Echo in Tower Plaza | Partial | Pulsing cyan veins creep across the plaza from the tower and climb its walls, with cyan spores in the air |
| Forest mist and leaves | Partial | Low mist along the river, in four hollows and over the Warden's yard; leaves drift down around Kael; Echo spores near the facility |
| Facility static and Chamber mist | Partial | Up to 14 dead monitors show rolling static; cyan mist lies on the Chamber floor |

Screenshot-checked in software rendering only; the frame-rate cost on the Mac is unmeasured (mist volumes are the most likely cost; Low preset turns volumetric fog off).

## M9 (1.3.0): photo mode, saving where you stand, Echo ghosts
Owner request: "go for next milestone and make bit more cool details to it".

| Feature | Status | Notes |
|---|---|---|
| Photo mode | Working | Pause > Photo mode: the world freezes, a free camera flies up to 14 m from Kael without passing through walls. Zoom, roll, six filters (None, Noir, Dusk, Cold, Echo, Faded film), widescreen bars, depth of field with adjustable focus, hide Kael, hide the panel, reset. Enter / A saves a PNG to the `photos` folder in the game's data folder. Keyboard, mouse and controller. Tested; filters checked in software screenshots. Saving a PNG has not been tried on the Mac |
| Save where you stand | Working | A save made on solid ground with nothing hunting Kael and no cinematic running brings him back to that exact spot and heading. Otherwise (mid-air, climbing, fighting) loading falls back to the last checkpoint, as before. Deaths still go back to the checkpoint. Tested |
| Echo ghosts | Partial | Faint cyan figures of people caught in their last moment, repeating it: two diner customers, a pupil and a teacher in the Learning Centre classroom, three people in Tower Plaza staring at the tower, a camper in the forest and up to three scientists at Facility desks. A whispered line fades in from 11 m; at 3.5 m the ghost scatters into motes with a soft swell and returns once Kael is 12 m away. Placed from `data/story/echo_ghosts.json`. Asleep beyond 45 m. No flicker with Reduce flashing. Screenshot only |
| Lightning bolts | Partial | Each lightning strike in the Dead City now draws a jagged, branching bolt in the sky ahead of the camera for half a second (none with Reduce flashing) |
| Hollows burn away | Partial | When a dead enemy fades, a cyan edge eats up through the body and embers rise from it |
| Bug fix: black screen | Working | A mesh built without normals could fill the glow pass with bad values and turn the frame black. The lightning bolt hit it; it now has normals, and no other generated mesh lacks them |

The ghosts are animated characters (up to 7 in the Dead City); their frame-rate cost on the Mac is unmeasured.

## M10 (1.4.0): New Game+, the wolf, more life in the world
Owner request: "add more details. also make the next step".

| Feature | Status | Notes |
|---|---|---|
| New Game+ | Working | Unlocked by finishing the game: Main menu > New Game+ starts again on the rooftop with Kael's weapons, their upgrade tiers and his salvage (+10). Health, stamina, cores and documents are found again. Each cycle gives enemies (bosses included) 35% more health and their hits 25% more damage, up to cycle 3. The cycle is saved with the run and shown on the pause menu's Inventory page. Tuning in `data/progression/new_game_plus.json`. Tested, including a boot from the menu; never played through |
| Wolf model | Working | The Forest's wolves are now four-legged wolves instead of reused skeleton models: a low-poly body with glowing Echo seams, eyes, ears, a jaw and tail, and their own clips (idle, walk, gallop, lunging bite with the jaw snapping on the hit, flinch, stagger, howl when alerted, roll-over death). Built by `tools/dev/build_wolf.gd`. Tested; seen in software screenshots |
| Crows | Partial | Small groups pick at the Dead City streets and sit on roof edges (ravens in five Forest clearings). They peck, hop and look about, and burst into the air with a clatter of wings (and sometimes a caw) when Kael comes within 7 m or a noise goes off nearby; they come back 30 s after he has gone. Tested; hard to see in the dark streets |
| Blowing newspapers | Partial | Old sheets skitter down the Dead City streets on the wind around Kael; none under cover or in the metro |
| Car hazard lights | Partial | Four abandoned cars still flash their amber hazards, lighting the street around them |
| Facility leaks | Partial | Water drips through missing ceiling tiles and along the corridors of Levels 1 and 2 into glossy puddles, with spreading rings and a plink when Kael is near. Tested |
| New sounds | Partial | Wings taking off, a crow's caw and two water drips, synthesized by `tools/assets/make_world_audio.py`. Never heard by a person |

Not measured on the Mac: up to 30 crows, 8 drips and the wolf rigs all add a little work.

## 1.4.1: renamed Ghostline
Owner request: "change the name of game to Ghostline in all places".

| Change | Status | Notes |
|---|---|---|
| New name | Working | Title screen, main menu, pause menu, loading screen, credits, final summary, the Mac app (`Ghostline.app`, bundle id `com.nikhilsharma.ghostline`), build output (`build/Ghostline.zip`), benchmark reports, photo file names and every doc. The story's "Echo" keeps its name |
| Saves carried over | Working | The data folder is now `Ghostline`. On the first launch `UserDataMigration` (the first autoload) copies everything from the old `TheLastEcho` folder if the new one has no settings yet, so saves, settings, the finished-game unlocks and New Game+ survive. The old folder is never changed. Tested |
