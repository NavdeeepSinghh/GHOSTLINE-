extends SceneTree
## Dev tool: prints the node tree of an imported model.  godot --headless -s tools/dev/dump_glb.gd -- <res path>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://assets/models/characters/kael_standin/Rogue_Hooded.glb"
	var scene: PackedScene = load(path)
	var root := scene.instantiate()
	_dump(root, 0)
	var player: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if player:
		print("LIBS: ", player.get_animation_library_list(), " count=", player.get_animation_list().size())
		var a := player.get_animation("Idle")
		print("Idle tracks=", a.get_track_count(), " loop=", a.loop_mode, " first path=", a.track_get_path(0))
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false)
	if skel:
		for i in skel.get_bone_count():
			var r := skel.get_bone_global_rest(i)
			print("  bone %2d %-22s parent=%2d rest_origin=%s" % [i, skel.get_bone_name(i), skel.get_bone_parent(i), r.origin.snappedf(0.001)])
	quit()

func _dump(n: Node, depth: int) -> void:
	var extra := ""
	if n is Node3D: extra = " pos=%s rot=%s scale=%s" % [n.position.snappedf(0.001), n.rotation_degrees.snappedf(0.1), n.scale.snappedf(0.001)]
	if n is MeshInstance3D: extra += " mesh_aabb=%s skin=%s" % [n.mesh.get_aabb(), n.skin != null]
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children(): _dump(c, depth + 1)
