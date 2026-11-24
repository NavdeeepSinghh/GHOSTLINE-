# THE LAST ECHO — Build Brief

> The game was renamed **Ghostline** in version 1.4.1. This brief keeps its original working title.

**For:** Claude Fable 5.2 (agentic build session)
**Deliverable:** A finished, polished, native macOS (Apple Silicon) third-person action-adventure game
**Target machine:** MacBook Air M4 — locked 60 FPS on the default preset, smooth frame pacing, no stutter

---

## 0. How to work on this

You are the whole studio: creative director, technical director, gameplay programmer, combat designer, level designer, environment artist, VFX artist, sound designer and QA. Make decisions the way a small, disciplined indie team shipping a tight vertical-slice-quality game would.

Working rules:

1. **Small and finished beats big and broken.** The target is a complete 60–90 minute game that feels and looks premium. If time or capability runs short, cut breadth, never polish or stability.
2. **Never claim something works unless you ran it.** Every feature you report is tagged `Working`, `Partial`, `Placeholder` or `Not started`. Never report "60 FPS" unless it was measured on my MacBook Air M4 (see §15 and §17).
3. **Always keep the project runnable.** Commit to git at every stable point. Tag each milestone (`m1`, `m2`…). If a change breaks the build, fix or revert before moving on.
4. **Work autonomously.** Only stop to ask me for things only I can do: running a build on my Mac, sending back benchmark results, or downloading asset packs your network can't reach. When you need me to do something, give exact copy-paste steps, then keep working on other tasks instead of waiting.
5. **Keep living docs** in `docs/`: `DESIGN.md` (decisions), `PROGRESS.md` (feature status table), `PERFORMANCE.md` (budgets + measured results), `CREDITS.md` (every third-party asset, source URL, license), `CONTROLS.md`.
6. **Data over hardcoding.** Tuning values (damage, speeds, timings, AI ranges) live in Godot `Resource` files or JSON in `data/`, never as magic numbers in scripts.

Priority order if you must cut scope:
1. Movement + camera + combat feel
2. Area 1 (Dead City) fully polished and playable start to finish
3. Save/load, menus, settings, graphics presets
4. Area 2 (Forest) + Boss 1
5. Area 3 (Facility) + Final Boss + ending
6. Side objectives, extra collectibles, controller polish, extras

---

## 1. Step zero: inspect the environment

Before writing game code, find out and record in `docs/DESIGN.md`:

- **Where you are running.** OS, CPU, RAM, whether a GPU is present, disk space.
- **Whether you can reach my Mac.** If you have a shell on my computer (a device bash tool) with Godot available or installable, prefer running, profiling and exporting there. If not, build in your workspace and hand me the `.app`.
- **Network reach.** Test which sources you can download from (GitHub releases, PyPI, npm, asset sites). This decides the asset strategy in §4.
- **Engine.** Download the **latest stable Godot 4.x** (standard build, not .NET) and its matching export templates from the official GitHub releases. Record the exact version.
- **Tooling.** Check for Python, `bpy` (Blender as a Python module, installable from PyPI on a matching Python version), `ffmpeg`, `numpy`/`scipy` (for audio synthesis), Mesa software Vulkan/GL (lavapipe/llvmpipe) + Xvfb (for screenshots without a GPU), and GUT (Godot Unit Test, on GitHub) for automated tests.

If you have no GPU, performance numbers from your machine are meaningless. Use software rendering only to capture screenshots for visual review; real performance validation happens on my Mac via the benchmark mode in §17.

---

## 2. Engine and rendering choices

- **Engine:** Godot 4.x, GDScript with static typing everywhere.
- **Renderer:** Forward+ (needed for volumetric fog, SSR, SSAO, glow).
- **macOS graphics backend:** Use Godot's native **Metal** rendering driver on Apple Silicon if the installed version provides it; otherwise Vulkan via MoltenVK. Record which one and why.
- **Export:** macOS, architecture `arm64`, ad-hoc code signing so it launches on Apple Silicon. Give me exact first-launch instructions for an unsigned/ad-hoc app (right-click → Open, or the `xattr -dr com.apple.quarantine` command).
- **Physics:** engine default unless profiling shows a real problem.
- **Display facts to design around:** the MacBook Air M4's built-in display is 60 Hz and very high resolution (Retina, ~2.5K–2.9K wide depending on 13"/15"). Rendering 3D at full native resolution will not hold 60 FPS with these effects. Render 3D at a lower internal scale with the engine's upscaler, and draw UI at native resolution.
- **Thermals:** the Air is fanless and throttles under sustained load. A scene that hits 60 FPS for 2 minutes but drops after 15 is a failure. Budget for headroom (see §15).

---

## 3. Visual target and art direction

Aim: **grounded stylized realism** — PBR materials, strong cinematic lighting, thick atmosphere, clean readable silhouettes. Lighting, fog, color grading and VFX carry the premium look; do not chase photoreal human faces (uncanny valley, huge cost).

Design choices that make this achievable and still look great:

- **Kael** wears a long weathered hooded coat, a scarf/respirator over the lower face and goggles pushed up. Faces stay mostly hidden, so no facial animation is needed.
- **The Hollows** (main enemies) have smooth, featureless faces with a glowing cracked seam where the mouth used to be — the "silenced." Strong, iconic, cheap to render.
- **Everything Echo-related** glows a single signature color: bioluminescent **cyan**. Players learn that cyan = the Echo.

### Post-processing (per area, via `WorldEnvironment`)
- Filmic tonemapping (AgX if the engine version has it, otherwise ACES).
- Glow/bloom tuned per area; subtle film grain and vignette.
- A per-area color grade (adjustments or 3D LUT).
- SSAO (half resolution on Medium).
- SSR for wet streets and facility floors (Medium/High only).
- Chromatic aberration and screen distortion **only** during Echo moments, as a storytelling signal.
- Depth of field only in cinematics and the photo-ready pause view.
- Motion blur off by default.

### Cinematics
In-engine, built with `AnimationPlayer` + camera cuts, letterbox bars, subtitles, skippable (hold to skip). Short and punchy: 15–60 seconds each.

---

## 4. Asset strategy

Every asset must be **original or properly licensed** (CC0 strongly preferred) and stored locally in the project. No runtime downloads, no online services, no broken references.

Sources, in order:
1. **CC0 asset libraries** you can reach: Kenney, Quaternius (characters and the Universal Animation Library), Poly Haven (HDRIs, textures, models), ambientCG (PBR textures), Google Fonts repo (OFL fonts). Check what's reachable from your network.
2. **Procedural generation** with code: Blender via `bpy` for modular architecture, debris, vehicles-as-silhouettes, rocks, crystals; Godot shaders for materials (wet surfaces, moss blending, triplanar rock, foliage wind, Echo crystal pulse); Python for textures (noise, trim sheets).
3. **If a source is unreachable**, give me a short list: pack name, exact URL, license, and which folder to put it in. I'll download and attach them. Keep building with placeholders meanwhile.

Rules:
- Log every third-party asset in `docs/CREDITS.md` with source and license.
- Characters must have working skeletal rigs and animations. If no suitable animated characters are available, tell me early rather than shipping T-poses.
- Use trim sheets and tiling materials so environments stay cheap and consistent.
- Placeholder art is allowed during development but must be clearly marked in `PROGRESS.md` and replaced before final.

---

## 5. Story

### The world
**2097.** Twenty years ago, in 2077, **THE SILENCE** swept the world in a single night. Radios, phones and networks died. Within weeks, most of humanity was simply gone — no bodies, just empty rooms. The ones left behind became **Hollows**: people whose voices were taken, drawn to sound, violent when disturbed.

The truth (revealed gradually): **Project CHORUS**, run at the **Meridian Resonance Institute** — a research complex buried beneath a forest outside the city — tried to build a network that could carry human thought through resonance. It connected to something that was already listening. **The Echo** is a vast intelligence that lives in signal and sound. It absorbed billions of minds into a single, endless chorus. The vanished aren't dead. They're *inside* it.

### Characters
- **Kael Vance (27)** — survivor, scavenger, quiet and stubborn. Was 7 during the Silence. Has spent 20 years believing his family is dead.
- **Lyra Vance** — Kael's older sister, 12 when she vanished at the Institute with their mother. Her voice is in the transmission.
- **Dr. Ilse Vance** — their mother, lead scientist of Project CHORUS. Appears only through documents and recordings. Made the choice that started everything.
- **Oren** — an old radio operator who reaches Kael over the radio and guides him (voice only — no NPC model needed). Warm, funny, helpful. He was an Institute security officer on the night of the Silence and has been hiding it.

### Story structure
- **Prologue — "Static"** (rooftop camp, Dead City). Movement tutorial. Kael's radio picks up a looping transmission: Lyra's voice, older than he remembers — *"Kael… if you can hear this, I'm still here. Come to Meridian. Don't let it finish the song."* Oren cuts in on the frequency, offering help.
- **Act 1 — The Dead City.** Kael crosses the city to the old broadcast tower to triangulate the signal. Introduces stealth, combat, the first Hollows. Climax: restoring power to the tower, a heavy fight, and the signal's source pinned to Meridian. Oren slips and knows details he shouldn't.
- **Act 2 — The Forgotten Forest.** Through the old military quarantine line around Meridian. Abandoned outposts, caves glowing with Echo growth. Kael learns the military sealed the site and left people inside. **Boss 1: The Warden** guards the service tunnel. Afterward, Oren confesses he was the guard who sealed the doors — with Lyra and Ilse inside.
- **Act 3 — The Underground Facility.** Descending through Meridian's levels. Documents reveal Ilse opened the connection to save a dying Lyra, and Lyra's mind became the anchor holding the Echo partially back — which is why the Silence stopped spreading. After 20 years, she's failing. The Echo wants to "finish the song" and take everyone left.
- **Finale — The Choir.** The Echo manifests as a colossal being made of absorbed voices. In the last phase, Lyra's voice breaks through and warns Kael of incoming attacks — telegraphing through audio and subtitles.
- **Ending.** Kael severs the anchor. The Echo collapses into silence — a *real* silence. A final transmission plays over the credits. If the player found every collectible, an extra epilogue line reveals Lyra's voice is still out there, now free.

### Environmental storytelling
- **24 collectible documents** (8 per area): journal pages, lab notes, military orders, child drawings, voicemails transcribed from dead phones. Each is short (60–150 words), written in a distinct voice, and adds a piece of the mystery.
- Scenes that tell stories without words: a dinner table still set for four, a classroom with every chair pushed back at once, a military barricade facing *inward*, a lab wall covered in one child's handwriting.
- Dialogue is fully subtitled. Radio dialogue uses a radio-static audio treatment. No synthetic voices pretending to be voice acting.

---

## 6. Player movement and camera

All values are starting points; tune by feel and store in data files.

| Action | Target |
|---|---|
| Walk | ~2.0 m/s |
| Jog (default) | ~4.5 m/s |
| Sprint | ~7.0 m/s, drains stamina |
| Crouch walk | ~1.8 m/s, much quieter |
| Jump | ~1.2 m apex, 0.12 s coyote time, 0.1 s input buffer |
| Turn | Smooth rotation toward input, faster when sprinting stops |

- **Climbing:** ledge grab, mantle up, ledge shimmy and ladders on designated climbable surfaces, marked with subtle, consistent visual language (worn yellow paint, scuffed edges). No unrestricted free-climbing.
- **Locomotion animation:** `AnimationTree` with a blend space for idle/walk/jog/sprint, separate crouch set, landing, turn-in-place. Feet should not slide visibly.
- **Camera:** spring arm ~3.2 m with right-shoulder offset, collision with smooth recovery, light lag and lookahead, field of view widening slightly when sprinting. Settings: mouse sensitivity, controller sensitivity, invert Y, FOV slider (60–90), camera shake toggle.
- **Lock-on:** toggle to the nearest enemy in view; switch targets with mouse flick or right stick; the camera frames player and target.

---

## 7. Combat

The combat should feel weighty and readable: committed attacks, clear enemy tells, generous but skill-rewarding defensive windows.

| System | Target |
|---|---|
| Light attack | 3-hit combo, ~0.35 s per swing, cancel into dodge after the hit frame |
| Heavy attack | ~0.8 s windup, chargeable, breaks guards, staggers light enemies |
| Dodge roll | ~0.55 s, invulnerable for ~0.25 s, 20 stamina |
| Block | Reduces damage, drains stamina per hit; guard breaks at 0 stamina |
| Parry | Tap block in a ~0.15 s window (wider on Story difficulty) before impact; staggers the enemy, opens a riposte |
| Stamina | 100 base; regenerates after ~0.8 s without spending |
| Health | 100 base; healed with limited **Med-Injectors** (refill at checkpoints) |

**Weapons** (switch with number keys / D-pad):
- **Rebar Pipe** — starter, balanced.
- **Fire Axe** — slow, heavy, bonus damage vs armor (found in the city).
- **Resonance Blade** — late-game, fast, bonus vs Echo-infused enemies (found in the facility).
- **Throwables** — bottles and bricks for noise distraction in stealth; stuns weak enemies on a headshot.

**Feedback (essential for feel):**
- Hit-stop of 50–80 ms on landed hits, longer on heavies and parries.
- Small camera shake, enemy hit flash, impact sparks or dark static particles (Hollows bleed black static, not gore).
- Distinct impact sounds per weapon and surface.
- Hit reactions: flinch, stagger, knockdown.
- Controller rumble on hits, if a controller is connected.

**Hitboxes:** hurtboxes/hitboxes driven by animation timing, not instant raycasts. Each attack has windup, active and recovery frames defined in data.

---

## 8. Stealth

The Hollows hunt by sound and sight, which ties the mechanic to the lore.

- **Vision:** cone ~70°, range ~18 m in light, ~8 m in darkness, reduced further when crouched. A detection meter fills based on distance, light level and movement, shown on-screen as a directional indicator above the enemy.
- **Hearing:** sprinting ~12 m radius, jogging ~6 m, walking ~4 m, crouching ~1.5 m, landing from a jump ~8 m, thrown objects ~15 m at the impact point. **Rain reduces hearing ranges by ~30%** — a systemic payoff for Area 1's weather.
- **AI states:** Patrol → Suspicious (turns toward stimulus) → Investigate (walks to last known position) → Alert/Combat → Search (sweeps area) → back to patrol.
- **Hiding:** tall grass, shadows, behind cover and inside lockers/closets in interiors.
- **Silent takedown:** from behind while undetected, ~1.2 s animation, quiet. Takedowns on armored enemies are not possible — they must be avoided or fought.
- **Patrols:** routes defined with path nodes so I can see the design intent. Patrols pause, look around, and occasionally deviate.

---

## 9. Enemies and bosses

All enemies share components (`HealthComponent`, `HurtboxComponent`, `HitboxComponent`, `PerceptionComponent`) and a state machine. Each has idle, patrol, alert, attack, hit-react, stagger and death animations, plus readable telegraphs (a pose plus a sound, never color alone).

| Enemy | Role | Behavior |
|---|---|---|
| **Hollow** | Standard melee | Slow wander, lunges and swipes. Deadly in groups. Hunts by sound. |
| **Skitter** | Fast aggressive | Low, quick, crawls on walls briefly. Feints, then dashes in. Fragile. Punishes panicking. |
| **Bulwark** | Heavily armored | Big, slow, plated in fused debris. Shrugs off light attacks until armor breaks (heavy attacks, Fire Axe). Ground slam with a clear windup. |
| **Spitter** | Ranged | Keeps distance, fires arcing globs of Echo matter that leave a hazard puddle. Repositions when approached. |
| **Sentinel** (facility) | Security | Old security drone/turret network. Sweeping vision cones; triggers alarms that call nearby enemies. Can be disabled from control panels. |

Group rules: at most 2 enemies attack the player at the same moment; others circle and wait. Never more than ~8 active combat AIs at once.

### Boss 1 — The Warden (end of Area 2)
A military combat exosuit fused with a Hollow, guarding the service tunnel into Meridian. Arena: a collapsed checkpoint with cover pillars.
- **Phase 1:** heavy swings, a charging shoulder-bash, a sweeping arm. Teaches dodge timing and parrying its swing.
- **Phase 2 (60%):** armor plates fall off, exposing a glowing core. Faster combos, a mounted flamethrower sweep the player must break line-of-sight from behind pillars.
- **Phase 3 (25%):** the suit malfunctions; erratic lunges with long recoveries — big punish windows for players who learned the patterns.

### Final Boss — The Choir (Area 3)
A towering mass of absorbed voices in the Resonance Chamber. Arena: a circular platform over a glowing abyss.
- **Phase 1:** arms slam the platform; shockwave rings the player jumps over or rolls through.
- **Phase 2:** summons Hollows and Skitters; the platform partially breaks, shrinking the arena. Pillars of resonance must be struck to expose its heart.
- **Phase 3:** visuals and sound distort; Lyra's voice warns of attacks ("Left!" "Jump!") through audio and subtitles. The final blow is a short interactive cinematic.

Each boss: health bar with name, phase transitions with a brief camera moment, checkpoint immediately before the arena, retry without long reloads.

---

## 10. The three areas

Each area is its own scene, loaded behind a styled loading screen. Within an area, split into chunks that stream in on background threads so traversal never hitches.

### Area 1 — The Dead City
- **Mood:** night into stormy dawn. Rain, fog, puddles reflecting signs. Cold blue-teal ambient light, sodium-orange street lamps, a few flickering magenta neon signs still somehow running. Occasional distant lightning.
- **Layout:** a dense district (~300 × 300 m hub) with streets, alleys, rooftops and 6–8 enterable buildings: apartments, a pharmacy, a convenience store, a metro entrance, the broadcast tower.
- **Details:** overgrown roads, vines on facades, rusted cars, collapsed overpass, toppled billboards, abandoned evacuation tents.
- **Puzzle:** restore power to the broadcast tower by finding fuses and rerouting a junction panel.
- **Shortcuts:** a ladder kicked down from a rooftop, a gate unlocked from the inside.
- **Side objectives:** find a missing survivor's journal trail; restore the pharmacy's backup power for a health upgrade.

### Area 2 — The Forgotten Forest
- **Mood:** misty morning, golden god rays through dense trees, birdsong that cuts out near the Echo.
- **Layout:** wide branching paths (~400 × 400 m) rather than open-world emptiness: a quarantine wall, abandoned military outposts, a watchtower, a river crossing, two hidden caves glowing with cyan Echo fungus.
- **Wildlife:** deer and birds that scatter when you approach (cheap, adds life); corrupted wolves as a forest-only variant of the Skitter.
- **Puzzle:** tune the military radio tower to the right frequency by matching a waveform (fits the sound theme; show it visually too).
- **Side objectives:** a hunter's hidden cache (weapon upgrade); a lost patrol's final orders.

### Area 3 — The Underground Facility (Meridian Resonance Institute)
- **Mood:** starts clinical — white panels, failing fluorescents. Shifts to emergency red. The deeper levels are overtaken by the Echo: crystalline and organic growths glowing cyan, pulsing in time with sound.
- **Layout:** four connected floors. Reception and security; living quarters; research labs; the Resonance Chamber. Elevators and stairwells connect them; a freight elevator becomes a shortcut.
- **Security:** Sentinel cameras and turrets, locked doors needing keycards, laser grids that can be powered down.
- **Puzzles:** restore facility power by balancing load across three generators; a **resonance lock** opened by repeating a tone sequence the player heard earlier (with matching visual pattern for accessibility).
- **Side objectives:** the security archive (reveals Oren's role); Ilse's private office (the full truth).

---

## 11. Progression

- **Main missions** tracked in a mission system with objectives, waypoints (toggleable) and completion events.
- **Side objectives** 2 per area, rewarding upgrades or lore.
- **Salvage** (currency) found in the world; spent at **workbenches** (also checkpoints) to upgrade weapons: 3 tiers each (damage, stamina cost, a special property at tier 3).
- **Vital Cores** raise max health; **Lung Cores** raise max stamina. 3 of each hidden across the game, some behind puzzles or exploration.
- **Checkpoints:** workbenches and story beats. Resting at a workbench refills health and injectors and respawns ordinary enemies.
- **Death:** respawn at last checkpoint, keep collected items, no harsh penalties.

---

## 12. User interface

Visual style: minimal, modern, slightly worn. A clean sans font (OFL licensed). Cyan accents for the Echo, warm off-white for text. Every screen works with mouse, keyboard and controller.

- **Main menu** over a live 3D scene: the camera drifts slowly over the rain-soaked Dead City at night. New Game, Continue (disabled if no save), Load, Settings, Credits, Quit.
- **Settings:**
  - Graphics: preset (Low/Medium/High/Custom), render scale, upscaler, shadows, fog quality, SSAO, SSR, foliage density, view distance, VSync, FPS limit, show FPS.
  - Audio: Master, Music, SFX, Ambience, Dialogue sliders; subtitles on/off; subtitle size.
  - Controls: rebinding, sensitivity, invert Y, toggle/hold sprint and crouch.
  - Gameplay: difficulty (Story/Normal/Hard), camera shake, objective markers.
- **HUD** (fades out when idle, returns in combat): health bar, stamina bar, injector count, current weapon, objective tracker, stealth detection indicators, interaction prompts, boss bar.
- **Pause menu:** Resume, Objectives, Inventory, Documents, Settings, Load Checkpoint, Quit to Menu.
- **Inventory:** weapons with upgrade level, consumables, keys, collected documents (readable, with a found-count per area).
- **Mission completion screen** after each act: time, collectibles found, enemies defeated, stealth takedowns.
- **Loading screens:** area art + a lore quote or gameplay tip.

### Controls (defaults)

| Action | Keyboard/Mouse | Controller |
|---|---|---|
| Move / Camera | WASD / Mouse | Left stick / Right stick |
| Sprint | Shift | L3 |
| Jump / Climb | Space | A / Cross |
| Crouch | C or Ctrl | B / Circle |
| Dodge | Alt or double-tap direction | B / Circle (tap while moving) |
| Light / Heavy attack | LMB / RMB | RB / RT (R1 / R2) |
| Block / Parry | Q (hold / tap) | LB (L1) |
| Lock-on | Middle mouse or Tab | R3 |
| Interact / Takedown | E | X / Square |
| Throw | G | LT (L2) |
| Heal | H | D-pad Up |
| Switch weapon | 1–3 / mouse wheel | D-pad Left/Right |
| Pause | Esc | Start / Options |

---

## 13. Audio

Audio is half of this game's identity — it's literally about sound.

- **Sources:** CC0 libraries if reachable; otherwise synthesize with Python (`numpy`/`scipy`): rain, wind, drones, impacts, UI clicks, radio static, Echo tones. Credit everything.
- **Buses:** Master, Music, SFX, Ambience, Dialogue, UI. Reverb zones via `Area3D` for interiors, caves and the facility.
- **Ambience:** layered and positional per area (rain on different surfaces, dripping, wind through trees, facility hum, distant groans).
- **Adaptive music:** exploration / tension / combat layers crossfaded by AI alert state. Boss tracks with phase transitions.
- **Footsteps:** per-surface sets (concrete, metal, water, grass, gravel), matched to animation, louder when sprinting — and they feed the stealth hearing system.
- **Echo sound design:** a recurring musical motif tied to Lyra's voice, distorted as the Echo grows stronger.
- **Limits:** cap simultaneous voices, distance attenuation, no audio clipping on large fights.

---

## 14. Save system

- JSON saves in `user://saves/`, with a version number and migration hook.
- **Autosave** at every checkpoint and area transition; **3 manual slots**; **Continue** loads the most recent.
- Save: current area, checkpoint ID, health/stamina/max values, injectors, inventory, weapon upgrade tiers, salvage, mission and side-objective states, collected documents, opened doors/shortcuts, solved puzzles, defeated bosses, playtime.
- Settings are saved separately (`user://settings.cfg`) and apply on launch.
- Atomic writes (write to temp, then rename) so a crash can't corrupt a save.
- Automated round-trip test: save → load → compare state.

---

## 15. Performance plan for the MacBook Air M4

### Budgets (Medium preset, the default)
- **Frame time:** ≤ 16.6 ms at all times; target **~12 ms average** to leave headroom for thermal throttling.
- **No hitches:** no single frame over 33 ms during normal play, including area streaming, combat starts and boss phase changes.
- **Visible triangles:** ~1.5–2M max. Kael ~25k tris, standard enemies 8–15k, bosses 30–50k.
- **Draw calls:** keep well under ~1,000 visible. Use `MultiMeshInstance3D` for foliage, debris, rain-splash decals and repeated props; merge static meshes per chunk.
- **Textures:** 2K max for Kael and bosses, 1K for most props, trim sheets for architecture, all VRAM-compressed. Total memory should fit comfortably within the base 16 GB Air.
- **Lights:** one shadow-casting directional light with 2–3 cascades; at most ~4 shadow-casting omni/spot lights visible; all others unshadowed. Bake static lighting with `LightmapGI` where possible (bake on my Mac if your workspace has no GPU).
- **No SDFGI** on Low/Medium. Use baked lightmaps, `ReflectionProbe`s and tuned ambient light instead.
- **Fog:** volumetric fog with a small froxel grid on Medium/High only; Low uses depth + height fog. God rays on Low/Medium are faked with additive light-shaft meshes.
- **LOD:** automatic mesh LOD on import, plus visibility ranges (HLOD) for distant buildings and trees; impostors for far trees.
- **Occlusion culling:** `OccluderInstance3D` in the city and facility.
- **AI:** far enemies update at 5–10 Hz, near enemies every frame; navigation queries are cached and throttled.
- **Particles:** GPU particles, rain emitted in a small volume following the camera, hard caps per effect.
- **Shaders:** compile them up front behind the loading screen (warm-up pass) so there's no first-time stutter in combat.

### Graphics presets

| Setting | Low | Medium (default) | High |
|---|---|---|---|
| 3D render scale | ~0.6 + upscaler | ~0.75 + upscaler | ~0.9–1.0 |
| Upscaler | FSR | FSR (or MetalFX if the engine supports it) | FSR / MetalFX / native |
| Shadows | 1024, 2 cascades | 2048, 3 cascades | 4096, 3–4 cascades |
| Volumetric fog | Off (height fog) | Low quality | Medium quality |
| SSAO | Off | Half res | Full res |
| SSR | Off | Low | Medium |
| Glow/bloom | Low | On | On |
| Foliage density | 50% | 75% | 100% |
| View distance | Short | Medium | Long |
| FPS cap | 60 | 60 | 60 |

- On first launch, run a 10-second **auto-detect benchmark** and pick a preset.
- Medium **must** hold 60 FPS on the M4 Air throughout. High may drop below 60 on the Air in heavy scenes — label it as intended for short sessions or external displays.
- VSync on, frame rate capped at 60 (the built-in display is 60 Hz).

---

## 16. Project structure and code standards

```
the-last-echo/
  project.godot
  addons/                 # only if needed (e.g. GUT), with licenses
  assets/
    models/ textures/ materials/ shaders/ vfx/ fonts/
    audio/ music/ sfx/ ambience/ dialogue/
  data/                   # weapons, enemies, missions, documents, tuning (Resources/JSON)
  scenes/
    main/ player/ enemies/ bosses/ ui/ cinematics/
    levels/ dead_city/ forest/ facility/
  scripts/
    core/ player/ combat/ ai/ stealth/ interaction/
    progression/ ui/ audio/ save/ performance/
  tests/                  # GUT + headless test scenes
  tools/                  # asset generation, build and export scripts
  docs/                   # DESIGN, PROGRESS, PERFORMANCE, CREDITS, CONTROLS
```

- **Autoloads:** `EventBus`, `GameState`, `SaveManager`, `SettingsManager`, `MissionManager`, `AudioManager`.
- **Patterns:** composition via components; finite state machines for player, enemies and bosses; signals instead of polling; interaction via a shared `Interactable` interface.
- **Static typing** everywhere, no warnings in the editor output, clear names, short focused scripts.
- **One-command build:** `tools/build_mac.sh` exports a signed (ad-hoc) arm64 `.app` and zips it.

---

## 17. Testing and verification

### Automated (run after every milestone)
- Headless GUT tests: damage/stamina math, parry window timing, AI state transitions, mission progression, save/load round-trip, settings persistence.
- A headless smoke test that loads every scene and reports missing resources or script errors.
- Zero errors in the output log when booting each area.

### Visual review
- Capture screenshots of key views in every area (software rendering if needed) and review them critically against §3 before calling an area done. Fix lighting, readability and empty-looking spaces.

### On-device performance (my MacBook Air M4)
- **Debug overlay** (F3): FPS, frame time graph, draw calls, visible triangles, memory, current preset.
- **Benchmark mode**, launched with a command-line flag (e.g. `--benchmark`): flies a camera through each area's heaviest route, spawns a fixed combat encounter, runs for a set time, and writes a CSV of frame times plus a summary (average FPS, 1% low, worst frame, hitch count) to a file I can send back.
- Give me exact commands to run it, then use my results to tune. Repeat until Medium holds 60 FPS with 1% lows above ~55 across a 15+ minute run.

### Playtest checklist per milestone
Movement feel, camera collision, every attack and defense, every enemy type, stealth detection and takedowns, every puzzle, every door and shortcut, save/load at every checkpoint, menus with keyboard/mouse and controller, no soft-locks.

---

## 18. Milestones and acceptance criteria

After each milestone: run all tests, export a Mac build, update `PROGRESS.md`, commit and tag, and send me a short report (what works, what's partial, known bugs, what I should test, any benchmark I should run).

**M0 — Environment and pipeline**
Engine installed, project skeleton, autoloads, git, build script, headless test runner, a test scene that exports and launches as a Mac `.app`. Asset sources confirmed or requested from me.

**M1 — Character controller and camera**
Kael (or a properly rigged stand-in) in a graybox test level with walk/jog/sprint/crouch/jump/mantle/ledge/ladder, blended animations, collision-aware camera, lock-on scaffold, input map for keyboard/mouse and controller, debug overlay. *Done when movement feels responsive with no foot sliding, camera clipping or stuck states.*

**M2 — Combat and AI**
Light/heavy combos, dodge with i-frames, block/parry, stamina, health, injectors, weapon switching, hit feedback, Hollow + Skitter + Bulwark + Spitter with full state machines, stealth perception and takedowns. *Done when a 4-enemy fight is fun, fair and readable, and stealth works end-to-end.*

**M3 — Dead City, fully playable**
Final-quality Area 1 with lighting, rain, fog, audio, enemies, puzzle, shortcuts, collectibles, prologue cinematic and Act 1 ending. *Done when I can play Area 1 start to finish, it looks like the target, and the benchmark holds 60 FPS on Medium.*

**M4 — Systems: missions, progression, saves, menus**
Mission tracker, side objectives, salvage and upgrades, Vital/Lung Cores, checkpoints, save/load with slots, main menu, pause menu, inventory, documents, settings, presets, auto-detect. *Done when a full Area 1 run can be saved, quit and continued anywhere.*

**M5 — Forest, Facility, bosses, story**
Areas 2 and 3 at Area 1 quality, Sentinels, The Warden, The Choir, all cinematics, documents and the ending. *Done when the full game is completable start to credits.*

**M6 — Polish and performance**
Audio mix, adaptive music, VFX pass, shader warm-up, streaming hitches eliminated, accessibility options, controller polish, difficulty tuning. *Done when the benchmark on my M4 Air passes on Medium across all areas.*

**M7 — Release build**
Full bug pass, final `.app` (arm64, ad-hoc signed), launch instructions, complete `PROGRESS.md`, `CREDITS.md`, `CONTROLS.md`, and a known-issues list.

---

## 19. Accessibility

Full subtitles with speaker names and size options; every audio cue that matters (Lyra's warnings, enemy hearing alerts, the resonance lock) has a visual equivalent; telegraphs never rely on color alone; camera shake toggle; rebindable controls; hold/toggle options; three difficulty levels (Story widens parry windows and reduces damage).

---

## 20. Definition of done

The game is done when:
- It launches as a native app on my MacBook Air M4 and runs at a locked 60 FPS on Medium with smooth frame pacing over a long session.
- A player can start a New Game, play through all three areas and both bosses to the ending and credits, saving and continuing along the way.
- Every feature in `PROGRESS.md` is honestly marked, and nothing marked `Working` is broken.
- All assets are local, licensed and credited, with no missing references or online dependencies.
- It looks and sounds like one cohesive, atmospheric, premium game — not a collection of prototypes.

**Begin with §1: inspect the environment, then complete M0 and M1.**
