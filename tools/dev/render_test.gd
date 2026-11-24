extends SceneTree
func _init() -> void:
	print("driver=", RenderingServer.get_current_rendering_driver_name(), " method=", RenderingServer.get_current_rendering_method(), " adapter=", RenderingServer.get_video_adapter_name())
	print("physics=", ProjectSettings.get_setting("physics/3d/physics_engine"))
	quit()
