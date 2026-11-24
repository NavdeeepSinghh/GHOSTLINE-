class_name CombatDirector
extends RefCounted
## Keeps group fights fair: only a couple of enemies may attack at the same
## moment. The rest circle and wait for a free slot.

const MAX_ATTACKERS: int = 2
## Most enemies that may be fighting or hunting Kael at once (performance and fairness).
const MAX_ENGAGED: int = 8

static var _attackers: Array[Node] = []
static var _engaged: Array[Node] = []


## Returns true if `enemy` may attack now (it then holds a slot until release()).
static func request(enemy: Node) -> bool:
	_purge()
	if _attackers.has(enemy):
		return true
	if _attackers.size() >= MAX_ATTACKERS:
		return false
	_attackers.append(enemy)
	return true


static func release(enemy: Node) -> void:
	_attackers.erase(enemy)


static func holds(enemy: Node) -> bool:
	return _attackers.has(enemy)


static func count() -> int:
	_purge()
	return _attackers.size()


static func clear() -> void:
	_attackers.clear()
	_engaged.clear()


## An enemy asks to join the fight. False when MAX_ENGAGED are already in it.
static func engage(enemy: Node) -> bool:
	for i: int in range(_engaged.size() - 1, -1, -1):
		if not is_instance_valid(_engaged[i]) or not _engaged[i].is_inside_tree():
			_engaged.remove_at(i)
	if _engaged.has(enemy):
		return true
	if _engaged.size() >= MAX_ENGAGED:
		return false
	_engaged.append(enemy)
	return true


static func disengage(enemy: Node) -> void:
	_engaged.erase(enemy)


static func engaged_count() -> int:
	return _engaged.size()


static func _purge() -> void:
	for i: int in range(_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_attackers[i]) or not _attackers[i].is_inside_tree():
			_attackers.remove_at(i)
