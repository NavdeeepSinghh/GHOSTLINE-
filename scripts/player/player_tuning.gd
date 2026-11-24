class_name PlayerTuning
extends Resource
## Every number that shapes how Kael moves. Edit data/player_tuning.tres in the
## inspector to tune feel; nothing here is hardcoded in the movement scripts.

@export_group("Ground movement")
## Metres per second.
@export var walk_speed: float = 2.0
@export var jog_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 1.8
@export var ground_acceleration: float = 30.0
@export var ground_deceleration: float = 38.0
## Radians per second the body turns toward the move direction.
@export var turn_speed: float = 13.0
@export var sprint_turn_speed: float = 7.5
## Analog stick tilt below this fraction walks instead of jogging.
@export_range(0.1, 0.9) var analog_walk_threshold: float = 0.55

@export_group("Jump and air")
## Peak height of a jump in metres.
@export var jump_apex_height: float = 1.2
@export var gravity: float = 24.0
## Extra gravity while falling makes jumps feel less floaty.
@export var fall_gravity_multiplier: float = 1.5
@export var max_fall_speed: float = 32.0
@export var air_acceleration: float = 11.0
## Seconds after leaving a ledge during which a jump still works.
@export var coyote_time: float = 0.12
## Seconds a jump press is remembered before touching the ground.
@export var jump_buffer_time: float = 0.1
## Landing faster than this (m/s) counts as a hard landing.
@export var hard_landing_speed: float = 11.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var sprint_stamina_per_second: float = 11.0
@export var stamina_regen_per_second: float = 28.0
## Seconds without spending before stamina starts to refill.
@export var stamina_regen_delay: float = 0.8
## Sprint cannot start below this much stamina.
@export var min_stamina_to_sprint: float = 12.0

@export_group("Body")
@export var stand_height: float = 1.75
## The stand-in model's large head keeps this high (data/player_tuning.tres uses
## 1.4); a realistically proportioned Kael will crouch to about 1.15.
@export var crouch_height: float = 1.15
@export var body_radius: float = 0.34
@export var floor_max_angle_degrees: float = 46.0
@export var step_height: float = 0.35

@export_group("Climbing")
## How far ahead the body looks for a climbable wall.
@export var ledge_reach: float = 0.7
## Ledges this high above the feet can be grabbed while airborne. These three
## values follow the character's arm reach; they suit the short-armed stand-in
## model and will grow with the final Kael model.
@export var ledge_grab_min_height: float = 0.8
@export var ledge_grab_max_height: float = 1.55
## Distance from the ledge down to the feet while hanging.
@export var hang_feet_offset: float = 1.0
## Obstacles in this height range are vaulted straight from the ground.
@export var mantle_min_height: float = 0.4
@export var mantle_max_height: float = 1.3
## While airborne, ledges at least this far above the feet can be pulled onto directly.
@export var air_mantle_min_height: float = 0.2
@export var shimmy_speed: float = 1.15
@export var ladder_speed: float = 2.1
@export var mantle_seconds_per_metre: float = 0.3
@export var mantle_min_duration: float = 0.32
## Seconds before a dropped ledge can be grabbed again.
@export var ledge_regrab_cooldown: float = 0.4

@export_group("Noise radius (metres, feeds stealth)")
@export var noise_sprint: float = 12.0
@export var noise_jog: float = 6.0
@export var noise_walk: float = 4.0
@export var noise_crouch: float = 1.5
@export var noise_landing: float = 8.0


## Launch speed that reaches jump_apex_height under gravity.
func get_jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_apex_height)
