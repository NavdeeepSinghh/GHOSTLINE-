class_name JunctionPuzzle
extends RefCounted
## The broadcast tower's junction panel: a row of relays. Throwing a breaker
## flips its own relay and its neighbours. Power flows when every relay is closed.

var relays: Array[bool] = []
var presses: int = 0


## Starts from the solved state and throws the breakers in `scramble`, so the
## puzzle is always solvable (throwing the same breakers again solves it).
func _init(relay_count: int = 5, scramble: Array = [0, 2, 3]) -> void:
	relays.resize(relay_count)
	relays.fill(true)
	for index: Variant in scramble:
		_flip_around(int(index))


func press(index: int) -> void:
	if index < 0 or index >= relays.size():
		return
	presses += 1
	_flip_around(index)


func is_solved() -> bool:
	return not relays.has(false)


func _flip_around(index: int) -> void:
	for neighbour: int in [index - 1, index, index + 1]:
		if neighbour >= 0 and neighbour < relays.size():
			relays[neighbour] = not relays[neighbour]
