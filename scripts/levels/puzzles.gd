class_name Puzzles
extends RefCounted
## Logic for the Forest and Facility puzzles, kept free of any interface so it can be tested.


## The military radio tower: turn two dials until the wave matches the target.
class Waveform extends RefCounted:
	const STEPS: int = 6
	var target_frequency: int = 4
	var target_amplitude: int = 2
	var frequency: int = 1
	var amplitude: int = 5

	func _init(want_frequency: int = 4, want_amplitude: int = 2) -> void:
		target_frequency = want_frequency
		target_amplitude = want_amplitude

	func turn_frequency(by: int) -> void:
		frequency = clampi(frequency + by, 1, STEPS)

	func turn_amplitude(by: int) -> void:
		amplitude = clampi(amplitude + by, 1, STEPS)

	func is_solved() -> bool:
		return frequency == target_frequency and amplitude == target_amplitude

	## Height of the wave (-1..1) at `x` (0..1) for the given dial positions.
	static func sample(x: float, at_frequency: int, at_amplitude: int) -> float:
		return sin(x * TAU * float(at_frequency)) * float(at_amplitude) / float(STEPS)


## Facility power: every load must sit on a generator without overloading any of them.
class LoadBalance extends RefCounted:
	var loads: Array[int] = [40, 30, 30, 20, 20, 10]
	var capacity: int = 50
	var generators: int = 3
	## Which generator each load is on (everything starts on the first one).
	var assignment: Array[int] = []

	func _init(load_values: Array = [], generator_capacity: int = 50) -> void:
		if not load_values.is_empty():
			loads.clear()
			for value: Variant in load_values:
				loads.append(int(value))
		capacity = generator_capacity
		assignment.resize(loads.size())
		assignment.fill(0)

	func cycle(load_index: int) -> void:
		if load_index >= 0 and load_index < assignment.size():
			assignment[load_index] = (assignment[load_index] + 1) % generators

	func total(generator: int) -> int:
		var sum: int = 0
		for i: int in loads.size():
			if assignment[i] == generator:
				sum += loads[i]
		return sum

	func is_solved() -> bool:
		for generator: int in generators:
			if total(generator) > capacity:
				return false
		return true


## The resonance lock: repeat a sequence of tones heard (and seen) earlier.
class ToneLock extends RefCounted:
	const SYMBOLS: PackedStringArray = ["▲", "■", "●", "◆"]
	var sequence: Array[int] = [2, 0, 3, 1]
	var entered: Array[int] = []
	var failures: int = 0

	func _init(wanted: Array = []) -> void:
		if not wanted.is_empty():
			sequence.clear()
			for value: Variant in wanted:
				sequence.append(int(value))

	## Returns true while the entry is still correct; a wrong tone clears it.
	func press(tone: int) -> bool:
		entered.append(tone)
		if entered[entered.size() - 1] != sequence[entered.size() - 1]:
			entered.clear()
			failures += 1
			return false
		return true

	func is_solved() -> bool:
		return entered.size() == sequence.size()

	func as_symbols() -> String:
		var text: PackedStringArray = []
		for tone: int in sequence:
			text.append(SYMBOLS[tone])
		return "  ".join(text)
