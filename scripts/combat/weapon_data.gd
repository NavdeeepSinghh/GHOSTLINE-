class_name WeaponData
extends Resource
## One melee weapon: damage, stamina costs and the timing of each swing.
## Times are seconds; an attack is windup -> active (can hit) -> recovery.

@export var id: String = "rebar_pipe"
@export var display_name: String = "Rebar Pipe"
## "pipe", "axe" or "blade": picks the procedural model.
@export var look: String = "pipe"

@export_group("Light attack")
@export var light_damage: float = 14.0
@export var light_stamina: float = 9.0
@export var light_poise: float = 12.0
## The three swings of the light combo.
@export var light_clips: PackedStringArray = ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]
@export var light_windup: float = 0.12
@export var light_active: float = 0.11
@export var light_recovery: float = 0.12
## Damage multiplier of the third swing.
@export var combo_finisher_multiplier: float = 1.4

@export_group("Heavy attack")
@export var heavy_damage: float = 34.0
@export var heavy_stamina: float = 24.0
@export var heavy_poise: float = 45.0
@export var heavy_clip: StringName = &"2H_Melee_Attack_Chop"
@export var heavy_windup: float = 0.8
@export var heavy_active: float = 0.14
@export var heavy_recovery: float = 0.42

@export_group("Reach")
## How far in front of Kael the hit volume is centred, and its radius.
@export var reach: float = 1.15
@export var hit_radius: float = 0.95

@export_group("Matchups")
## Multiplier against armour plating (Bulwarks).
@export var armor_multiplier: float = 1.0
## Multiplier against Echo-infused enemies.
@export var echo_multiplier: float = 1.0


func get_light_swing_time() -> float:
	return light_windup + light_active + light_recovery
