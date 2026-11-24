extends Node
## The mission tracker: one main objective (with an optional waypoint), a list
## of side objectives, and a log of what has been done. Levels drive it; the
## HUD and the pause menu read it. It is rebuilt from the level's saved stage
## on load, so it is not written to the save file itself.

signal objective_changed(text: String)
signal changed

var mission_title: String = ""
var current_objective: String = ""
## World position the objective marker points at, or null for none.
var waypoint: Variant = null
## Objectives already completed in this mission, oldest first.
var completed: Array[String] = []
## id -> {"text": String, "done": bool}
var side_objectives: Dictionary = {}


func reset() -> void:
	mission_title = ""
	current_objective = ""
	waypoint = null
	completed.clear()
	side_objectives.clear()
	changed.emit()


func set_objective(text: String, marker: Variant = null) -> void:
	waypoint = marker
	if text == current_objective:
		changed.emit()
		return
	current_objective = text
	objective_changed.emit(text)
	changed.emit()


func set_completed(done: Array[String]) -> void:
	completed = done
	changed.emit()


## Adds or updates a side objective. Hidden ones are simply never added.
func set_side(id: String, text: String, done: bool) -> void:
	side_objectives[id] = {"text": text, "done": done}
	changed.emit()


func is_side_done(id: String) -> bool:
	return bool((side_objectives.get(id, {}) as Dictionary).get("done", false))


## The first unfinished side objective's text, for the HUD's second line.
func active_side_text() -> String:
	for id: String in side_objectives:
		if not bool(side_objectives[id]["done"]):
			return str(side_objectives[id]["text"])
	return ""
