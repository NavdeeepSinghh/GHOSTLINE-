class_name CombatTuning
extends Resource
## Numbers that shape Kael's side of combat: defence windows, feedback and
## healing. Weapon numbers live in data/weapons, enemy numbers in data/enemies.

@export_group("Health and healing")
@export var max_health: float = 100.0
@export var max_injectors: int = 3
@export var injector_heal: float = 45.0
## Seconds the injector takes; being hit interrupts it.
@export var injector_time: float = 0.9
## Seconds of invulnerability after taking a hit.
@export var hurt_invulnerable_time: float = 0.45

@export_group("Dodge")
@export var dodge_duration: float = 0.55
@export var dodge_distance: float = 4.4
@export var dodge_stamina: float = 20.0
## Invulnerable from this many seconds into the dodge...
@export var dodge_iframe_start: float = 0.03
## ...for this long.
@export var dodge_iframe_duration: float = 0.25
## Two taps of the same direction within this many seconds start a dodge (if enabled in Controls).
@export var double_tap_window: float = 0.25

@export_group("Block and parry")
## Fraction of damage that still gets through a block.
@export var block_damage_multiplier: float = 0.25
## Stamina lost per point of blocked damage.
@export var block_stamina_per_damage: float = 1.1
@export var block_move_speed: float = 1.6
## A hit landing this soon after raising the guard is a parry.
@export var parry_window: float = 0.15
@export var parry_window_story: float = 0.3
## Raising the guard again sooner than this cannot parry (stops button mashing).
@export var parry_rearm_time: float = 0.35
## Attacks from behind this angle (degrees from facing) cannot be blocked.
@export var block_arc_degrees: float = 75.0
@export var guard_break_time: float = 1.0

@export_group("Hit reactions")
@export var flinch_time: float = 0.32
@export var stagger_time: float = 0.75
## Poise damage at or above this staggers instead of flinching.
@export var stagger_poise: float = 30.0
@export var knockback_flinch: float = 2.5
@export var knockback_stagger: float = 5.5

@export_group("Feedback")
@export var hitstop_light: float = 0.06
@export var hitstop_heavy: float = 0.09
@export var hitstop_parry: float = 0.12
@export var shake_light: float = 0.12
@export var shake_heavy: float = 0.3

@export_group("Attack input")
## Seconds an attack press is remembered (lets combos chain without perfect timing).
@export var attack_buffer_time: float = 0.3
## Extra seconds a heavy attack can be held to charge.
@export var heavy_charge_time: float = 0.9
## Damage bonus at full charge (0.6 = +60%).
@export var heavy_charge_bonus: float = 0.6

@export_group("Stealth")
@export var takedown_range: float = 1.8
@export var takedown_duration: float = 1.2
@export var max_throwables: int = 3
@export var throw_speed: float = 15.0
@export var throw_cooldown: float = 0.7
@export var throw_noise_radius: float = 15.0
@export var throw_stun_time: float = 2.2

@export_group("Difficulty: damage Kael takes")
@export var damage_taken_story: float = 0.5
@export var damage_taken_normal: float = 1.0
@export var damage_taken_hard: float = 1.5


func get_parry_window() -> float:
	return parry_window_story if SettingsManager.get_value("gameplay", "difficulty") == "story" else parry_window


func get_damage_taken_multiplier() -> float:
	match str(SettingsManager.get_value("gameplay", "difficulty")):
		"story": return damage_taken_story
		"hard": return damage_taken_hard
	return damage_taken_normal
