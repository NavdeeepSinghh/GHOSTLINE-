class_name HitInfo
extends RefCounted
## Everything a target needs to know about one incoming hit.

enum Result { IGNORED, HIT, BLOCKED, PARRIED, ARMORED, KILLED }

var damage: float = 0.0
var poise: float = 10.0
var attacker: Node3D
## World position the hit came from (for knockback and block direction).
var origin: Vector3
var is_heavy: bool = false
var armor_multiplier: float = 1.0
var echo_multiplier: float = 1.0
var can_be_blocked: bool = true
var can_be_parried: bool = true
var breaks_guard: bool = false
## Seconds of stun applied on a clean hit (thrown objects).
var stun: float = 0.0


func duplicate_hit() -> HitInfo:
	var copy := HitInfo.new()
	copy.damage = damage
	copy.poise = poise
	copy.attacker = attacker
	copy.origin = origin
	copy.is_heavy = is_heavy
	copy.armor_multiplier = armor_multiplier
	copy.echo_multiplier = echo_multiplier
	copy.can_be_blocked = can_be_blocked
	copy.can_be_parried = can_be_parried
	copy.breaks_guard = breaks_guard
	copy.stun = stun
	return copy


static func landed(result: Result) -> bool:
	return result == Result.HIT or result == Result.KILLED or result == Result.ARMORED
