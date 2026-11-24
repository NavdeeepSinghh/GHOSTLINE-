class_name CameraTuning
extends Resource
## Numbers that shape the third-person camera. Edit data/camera_tuning.tres.

@export_group("Framing")
## Distance from the pivot to the camera in metres.
@export var distance: float = 3.2
## Sideways offset so Kael sits left of centre (over-the-shoulder).
@export var shoulder_offset: float = 0.45
## Height of the point the camera orbits, above the feet.
@export var focus_height: float = 1.45
@export var crouch_focus_height: float = 1.05
@export var default_pitch_degrees: float = -12.0
@export var min_pitch_degrees: float = -68.0
@export var max_pitch_degrees: float = 38.0

@export_group("Follow")
## Higher follows tighter. Vertical is looser so steps and jumps feel smooth.
@export var follow_speed_horizontal: float = 16.0
@export var follow_speed_vertical: float = 8.0
## Seconds of movement the camera looks ahead by.
@export var lookahead_seconds: float = 0.1
@export var max_lookahead: float = 0.6

@export_group("Look")
## Radians per pixel of mouse movement at sensitivity 1.
@export var mouse_radians_per_pixel: float = 0.0023
## Radians per second at full stick tilt.
@export var stick_yaw_speed: float = 2.9
@export var stick_pitch_speed: float = 1.9

@export_group("Collision")
@export var collision_radius: float = 0.2
## Metres per second the camera eases back out after an obstruction clears.
@export var recover_speed: float = 5.0
## Below this camera distance the character fades out instead of filling the view.
@export var fade_start_distance: float = 1.1
@export var fade_end_distance: float = 0.55

@export_group("Feel")
## Extra field of view (degrees) at full sprint.
@export var sprint_fov_boost: float = 6.0
@export var max_shake_degrees: float = 2.2
## How fast shake trauma decays per second.
@export var shake_decay: float = 1.6

@export_group("Lock-on")
@export var lock_on_range: float = 18.0
@export var lock_on_turn_speed: float = 9.0
## Mouse pixels in one flick that switch to the next target.
@export var lock_on_flick_pixels: float = 70.0
## Seconds without line of sight before the lock drops.
@export var lock_on_lost_seconds: float = 1.2
