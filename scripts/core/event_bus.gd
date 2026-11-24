extends Node
## Global signal hub. Systems talk through these signals instead of holding
## references to each other, which keeps them reusable and testable.

# --- Player ---
@warning_ignore("unused_signal")
signal player_spawned(player: Node3D)
@warning_ignore("unused_signal")
signal player_state_changed(previous: StringName, current: StringName)
@warning_ignore("unused_signal")
signal player_landed(impact_speed: float)
@warning_ignore("unused_signal")
signal stamina_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal health_changed(current: float, maximum: float)

# --- Combat ---
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal player_respawned
@warning_ignore("unused_signal")
signal injectors_changed(count: int, maximum: int)
@warning_ignore("unused_signal")
signal throwables_changed(count: int, maximum: int)
@warning_ignore("unused_signal")
signal weapon_changed(weapon: Resource)
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node3D)

# --- Stealth (consumed by enemy perception in Milestone 2) ---
@warning_ignore("unused_signal")
signal noise_emitted(position: Vector3, radius: float, source: Node)

# --- Interaction / UI ---
@warning_ignore("unused_signal")
signal interaction_prompt_changed(text: String)
@warning_ignore("unused_signal")
signal toast_requested(text: String, seconds: float)
@warning_ignore("unused_signal")
signal lock_on_changed(target: Node3D)
@warning_ignore("unused_signal")
signal pause_changed(is_paused: bool)

# --- World / progression ---
@warning_ignore("unused_signal")
signal checkpoint_reached(checkpoint_id: StringName)
@warning_ignore("unused_signal")
signal camera_shake_requested(trauma: float)

# --- Story (Milestone 3) ---
## `lines`: Array of {"speaker": String, "text": String, "seconds": float, "sound": String (optional)}.
@warning_ignore("unused_signal")
signal dialogue_requested(lines: Array)
@warning_ignore("unused_signal")
signal hint_requested(text: String, seconds: float)
@warning_ignore("unused_signal")
signal document_collected(document: Dictionary)
@warning_ignore("unused_signal")
signal objective_changed(text: String, side_text: String)
@warning_ignore("unused_signal")
signal takedown_performed
@warning_ignore("unused_signal")
signal cinematic_changed(is_playing: bool)
## A full-screen panel (document, puzzle, summary) opened or closed.
@warning_ignore("unused_signal")
signal modal_changed(is_open: bool)

## Fade the screen to black (amount 1) or back in (amount 0).
@warning_ignore("unused_signal")
signal fade_requested(amount: float, seconds: float)
@warning_ignore("unused_signal")
signal area_title_requested(heading: String, sub: String)
## `rows`: Array of [label, value].
@warning_ignore("unused_signal")
signal act_completed(title: String, rows: Array)

## Kael rested at a workbench (the interface opens the upgrade panel).
@warning_ignore("unused_signal")
signal workbench_used(player: Node3D)

@warning_ignore("unused_signal")
signal upgrade_purchased(weapon_id: String)

## Leave this area for another ("dead_city", "forest", "facility").
@warning_ignore("unused_signal")
signal travel_requested(area: String)
@warning_ignore("unused_signal")
signal boss_started(boss_name: String)
@warning_ignore("unused_signal")
signal boss_health_changed(ratio: float)
@warning_ignore("unused_signal")
signal boss_ended
## The story is over: roll the credits.
@warning_ignore("unused_signal")
signal credits_requested(epilogue: bool)

# --- Tools ---
@warning_ignore("unused_signal")
signal benchmark_finished(summary: Dictionary)
