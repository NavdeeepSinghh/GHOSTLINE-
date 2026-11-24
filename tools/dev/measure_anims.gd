extends SceneTree
## Dev tool: estimates the natural ground speed of locomotion clips from foot travel
## during the stance phase, so blend points can be placed without foot sliding.
const CLIPS := ["Walking_A", "Walking_B", "Walking_C", "Walking_Backwards", "Running_A", "Running_B", "Running_Strafe_Left", "Running_Strafe_Right"]

func _initialize() -> void:
	_run()

func _run() -> void:
	var scene: PackedScene = load("res://assets/models/characters/kael_standin/Rogue_Hooded.glb")
	var model := scene.instantiate()
	root.add_child(model)
	await process_frame
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var foot := skel.find_bone("foot.l")
	var hips := skel.find_bone("hips")
	var head := skel.find_bone("head")
	for clip: String in CLIPS:
		var anim := player.get_animation(clip)
		player.play(clip)
		var samples: Array[Vector3] = []
		var steps := int(anim.length * 120.0)
		var min_y := INF
		for i in steps + 1:
			player.seek(anim.length * float(i) / steps, true)
			var p := skel.get_bone_global_pose(foot).origin
			samples.append(p)
			min_y = minf(min_y, p.y)
		var total := Vector3.ZERO
		var count := 0
		for i in range(1, samples.size()):
			if samples[i].y < min_y + 0.015 and samples[i - 1].y < min_y + 0.015:
				total += (samples[i] - samples[i - 1]) * 120.0
				count += 1
		var v := total / maxf(count, 1)
		player.seek(0.0, true)
		print("%-22s len=%.2f stance_frames=%3d foot_vel=(%.2f, %.2f) speed=%.2f  hips_y=%.3f hips_z_range=%.3f" % [clip, anim.length, count, v.x, v.z, Vector2(v.x, v.z).length(), skel.get_bone_global_pose(hips).origin.y, 0.0])
	for clip: String in ["Idle", "Jump_Idle", "Jump_Start", "Jump_Land", "Unarmed_Idle", "2H_Melee_Idle"]:
		player.play(clip)
		player.seek(0.0, true)
		var hl := skel.get_bone_global_pose(skel.find_bone("wrist.l")).origin
		print("%-14s t0 hips=%s head=%s wrist.l=%s foot.l=%s" % [clip, skel.get_bone_global_pose(hips).origin.snappedf(0.01), skel.get_bone_global_pose(head).origin.snappedf(0.01), hl.snappedf(0.01), skel.get_bone_global_pose(foot).origin.snappedf(0.01)])
	quit()
