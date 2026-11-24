class_name EnemyData
extends Resource
## One enemy type: body, senses, movement, its attack and its animation clips.
## New enemy types are new .tres files in data/enemies, not new scripts.

enum AttackKind { MELEE, DASH, SLAM, RANGED }

@export var id: String = "hollow"
@export var display_name: String = "Hollow"
@export var model: PackedScene
@export var model_scale: float = 0.8
@export var body_radius: float = 0.36
@export var body_height: float = 1.7
@export var eye_height: float = 1.45
## Extra damage from the Resonance Blade applies to Echo-infused enemies.
@export var is_echo_infused: bool = false

@export_group("Health and defence")
@export var max_health: float = 45.0
## Armour plating points. While above zero, light attacks barely scratch.
@export var armor: float = 0.0
## Fraction of light-attack damage that gets through armour.
@export var armor_light_multiplier: float = 0.2
## Poise damage that builds up to a stagger.
@export var stagger_threshold: float = 30.0
## False for enemies that shrug off ordinary hits without flinching.
@export var flinches: bool = true
@export var stunnable: bool = true
@export var takedown_allowed: bool = true
@export var flinch_time: float = 0.35
@export var stagger_time: float = 1.4
@export var parried_stagger_time: float = 1.7

@export_group("Movement")
@export var walk_speed: float = 1.1
@export var chase_speed: float = 3.4
## Radians per second.
@export var turn_speed: float = 6.0

@export_group("Senses")
@export var vision_range: float = 18.0
@export var vision_range_dark: float = 8.0
## Full width of the vision cone in degrees.
@export var vision_fov_degrees: float = 70.0
## Seconds to fully notice a moving target at mid range.
@export var detect_time: float = 1.1
## A crouched target hidden in cover is only seen inside this distance.
@export var hidden_detect_range: float = 1.6
## Multiplier on how far away noises are heard.
@export var hearing: float = 1.0
## Seconds without sight before giving up the chase and searching.
@export var lose_target_time: float = 4.0
## Allies within this distance are alerted when this enemy spots the player.
@export var alert_radius: float = 9.0

@export_group("Attack")
@export var attack_kind: AttackKind = AttackKind.MELEE
@export var attack_damage: float = 14.0
@export var attack_poise: float = 16.0
## Distance at which the attack starts.
@export var attack_range: float = 1.7
@export var attack_windup: float = 0.55
@export var attack_active: float = 0.15
@export var attack_recovery: float = 0.6
@export var attack_cooldown: float = 1.4
## Forward speed during the active part (a lunge or a dash).
@export var attack_lunge_speed: float = 3.5
@export var attack_reach: float = 1.2
@export var attack_radius: float = 0.9
@export var attack_breaks_guard: bool = false
## SLAM: radius of the shockwave around the enemy.
@export var slam_radius: float = 3.0
## RANGED: keeps between these distances from the target.
@export var ranged_min_distance: float = 5.0
@export var ranged_max_distance: float = 11.0
@export var projectile_flight_time: float = 0.9

@export_group("Animation clips")
@export var idle_clip: StringName = &"Idle"
@export var walk_clip: StringName = &"Walking_D_Skeletons"
@export var run_clip: StringName = &"Running_A"
@export var attack_clip: StringName = &"Unarmed_Melee_Attack_Punch_A"
## Fraction of the attack clip at which it connects.
@export var attack_impact_fraction: float = 0.4
@export var hit_clip: StringName = &"Hit_A"
@export var stagger_clip: StringName = &"Hit_B"
@export var death_clip: StringName = &"Death_C_Skeletons"
@export var alert_clip: StringName = &"Taunt"
## Ground speed the walk and run clips were authored for (m/s), to avoid foot sliding.
@export var walk_clip_speed: float = 1.2
@export var run_clip_speed: float = 4.2

@export_group("Wall perch")
## How close Kael must come, in sight, before a perched enemy leaps down.
@export var perch_notice_range: float = 11.0
## How long the leap from the wall takes.
@export var perch_drop_seconds: float = 0.6
