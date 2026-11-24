class_name HitboxComponent
extends Node
## A melee hit volume driven by attack timing: the owner calls begin() when the
## swing becomes dangerous and end() when it stops. While active, anything in
## the volume with a receive_hit(HitInfo) method is hit once per swing.

signal hit_landed(target: Node3D, result: HitInfo.Result, hit: HitInfo)

## Height of the volume's centre above the owner's feet.
@export var height: float = 1.0

var is_active: bool = false

var _body: CharacterBody3D
var _hit: HitInfo
var _reach: float = 1.0
var _radius: float = 0.9
var _mask: int = 0
var _already_hit: Array[Node] = []
var _shape := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_query.shape = _shape


## `mask` is the physics layer(s) of the bodies this swing can hurt.
func begin(hit: HitInfo, reach: float, radius: float, mask: int) -> void:
	_hit = hit
	_reach = reach
	_radius = radius
	_mask = mask
	_already_hit.clear()
	is_active = true


func end() -> void:
	is_active = false


func _physics_process(_delta: float) -> void:
	if is_active:
		sweep()


## Checks the volume once. Returns how many targets were struck this call.
func sweep() -> int:
	var facing: Vector3 = _body.call(&"get_facing_direction")
	var center: Vector3 = _body.global_position + Vector3.UP * height + facing * _reach * 0.55
	_shape.radius = _radius
	_query.transform = Transform3D(Basis.IDENTITY, center)
	_query.collision_mask = _mask
	_query.exclude = [_body.get_rid()]
	var struck: int = 0
	for found: Dictionary in _body.get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var target: Node = found["collider"]
		if target == null or _already_hit.has(target) or not target.has_method(&"receive_hit"):
			continue
		_already_hit.append(target)
		var hit: HitInfo = _hit.duplicate_hit()
		hit.origin = _body.global_position
		var result: HitInfo.Result = target.call(&"receive_hit", hit)
		if result != HitInfo.Result.IGNORED:
			struck += 1
			hit_landed.emit(target as Node3D, result, hit)
	return struck
