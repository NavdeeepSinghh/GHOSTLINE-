class_name CityFX
extends RefCounted
## Builders for small atmospheric effects: steam from grates, fires, smoke
## columns, warning beacons, emergency lights and distant searchlights. Each
## returns a node that the caller adds to the scene. No textures are loaded;
## the soft particle sprite is a generated radial gradient.

## Particle counts follow the graphics preset (Low halves them).
static func amount_scale() -> float:
	match str(SettingsManager.get_value("graphics", "preset")):
		"low":
			return 0.5
		"high":
			return 1.3
	return 1.0


## Built per use, not cached: a static cache outlives the scene and is
## reported as a leaked resource at exit.
static func soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64
	return soft


static func _ramp(points: Array) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for point: Array in points:
		offsets.append(float(point[0]))
		colors.append(point[1] as Color)
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _sprite_material(additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_texture()
	material.disable_receive_shadows = true
	return material


static func _particles(amount: int, lifetime: float, process: ParticleProcessMaterial, size: float,
		additive: bool, bounds: AABB) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _sprite_material(additive)
	particles.draw_pass_1 = quad
	particles.visibility_aabb = bounds
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Steam rising out of a grate or manhole: thin wisps that spread as they rise.
static func steam(at: Vector3, amount: int = 16) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.45, 0.05, 0.45)
	process.direction = Vector3.UP
	process.spread = 8.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.3
	process.gravity = Vector3(0.25, 0.15, 0.05)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 4.0
	process.scale_min = 0.5
	process.scale_max = 0.9
	process.scale_curve = _curve([Vector2(0.0, 0.25), Vector2(1.0, 1.0)])
	process.color_ramp = _ramp([[0.0, Color(0.6, 0.64, 0.68, 0.0)], [0.15, Color(0.58, 0.62, 0.66, 0.07)],
			[0.6, Color(0.55, 0.58, 0.62, 0.05)], [1.0, Color(0.5, 0.53, 0.57, 0.0)]])
	var particles := _particles(amount, 6.0, process, 3.4, false, AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8)))
	particles.position = at
	return particles


## A fire: flames, rising embers and a flickering light.
static func fire(at: Vector3, size: float = 1.0, light_energy: float = 2.6) -> Node3D:
	var root := Node3D.new()
	root.position = at
	var flame := ParticleProcessMaterial.new()
	flame.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.35 * size
	flame.direction = Vector3.UP
	flame.spread = 10.0
	flame.initial_velocity_min = 0.8 * size
	flame.initial_velocity_max = 1.6 * size
	flame.gravity = Vector3(0.0, 1.2, 0.0)
	flame.scale_min = 0.6
	flame.scale_max = 1.0
	flame.scale_curve = _curve([Vector2(0.0, 0.6), Vector2(0.3, 1.0), Vector2(1.0, 0.1)])
	flame.color_ramp = _ramp([[0.0, Color(1.0, 0.85, 0.45, 0.0)], [0.12, Color(1.0, 0.62, 0.22, 0.9)],
			[0.55, Color(0.95, 0.26, 0.06, 0.55)], [1.0, Color(0.25, 0.06, 0.02, 0.0)]])
	root.add_child(_particles(int(28 * size) + 6, 0.8, flame, 0.9 * size, true, AABB(Vector3(-2, -1, -2) * size, Vector3(4, 5, 4) * size)))
	var embers := ParticleProcessMaterial.new()
	embers.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.4 * size
	embers.direction = Vector3.UP
	embers.spread = 28.0
	embers.initial_velocity_min = 1.5
	embers.initial_velocity_max = 3.5
	embers.gravity = Vector3(0.3, 0.4, 0.0)
	embers.turbulence_enabled = true
	embers.turbulence_noise_strength = 1.2
	embers.scale_min = 0.5
	embers.scale_max = 1.0
	embers.color_ramp = _ramp([[0.0, Color(1.0, 0.75, 0.3, 1.0)], [0.7, Color(1.0, 0.35, 0.08, 0.8)], [1.0, Color(0.6, 0.1, 0.02, 0.0)]])
	root.add_child(_particles(int(14 * size) + 4, 2.4, embers, 0.07, true, AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))))
	var light := FireLight.new()
	light.position = Vector3(0.0, 0.9 * size, 0.0)
	light.light_color = Color(1.0, 0.5, 0.18)
	light.light_energy = light_energy
	light.omni_range = 8.0 * size
	light.omni_attenuation = 1.4
	light.light_volumetric_fog_energy = 1.6
	light.distance_fade_enabled = true
	light.distance_fade_begin = 60.0
	light.distance_fade_length = 15.0
	root.add_child(light)
	return root


## A tall column of smoke for distant fires on the skyline.
static func smoke_column(at: Vector3, height: float = 45.0, width: float = 7.0) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = width * 0.3
	process.direction = Vector3.UP
	process.spread = 6.0
	process.initial_velocity_min = height / 16.0
	process.initial_velocity_max = height / 11.0
	process.gravity = Vector3(0.6, 0.0, 0.2)
	process.scale_min = 0.7
	process.scale_max = 1.2
	process.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(1.0, 1.6)])
	process.color_ramp = _ramp([[0.0, Color(0.55, 0.25, 0.1, 0.0)], [0.08, Color(0.35, 0.18, 0.1, 0.5)],
			[0.35, Color(0.09, 0.09, 0.1, 0.45)], [1.0, Color(0.05, 0.05, 0.06, 0.0)]])
	var particles := _particles(30, 14.0, process, width, false,
			AABB(Vector3(-width * 3.0, -2.0, -width * 3.0), Vector3(width * 6.0 + 20.0, height * 1.6, width * 6.0)))
	particles.position = at
	return particles


## A small glowing sphere, optionally blinking.
static func glow_bulb(at: Vector3, color: Color, radius: float = 0.3, energy: float = 4.0) -> MeshInstance3D:
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color * energy
	sphere.material = material
	bulb.mesh = sphere
	bulb.position = at
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bulb


## A red aircraft-warning beacon that blinks.
static func beacon(at: Vector3, radius: float = 0.6, phase: float = 0.0) -> Blinker:
	var blinker := Blinker.new()
	blinker.position = at
	blinker.period = 1.8
	blinker.duty = 0.3
	blinker.phase = phase
	blinker.add_child(glow_bulb(Vector3.ZERO, Color(1.0, 0.08, 0.05), radius, 5.0))
	return blinker


## Emergency lights on a wrecked car roof: a light bar and a strobing light.
static func emergency_lights(at: Vector3, yaw_degrees: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = deg_to_rad(yaw_degrees)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.2, 0.12, 0.26)
	var bar_material := StandardMaterial3D.new()
	bar_material.albedo_color = Color(0.08, 0.08, 0.09)
	bar_mesh.material = bar_material
	bar.mesh = bar_mesh
	root.add_child(bar)
	var light := StrobeLight.new()
	light.position = Vector3(0.0, 0.5, 0.0)
	light.light_energy = 3.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.3
	light.light_volumetric_fog_energy = 1.2
	light.distance_fade_enabled = true
	light.distance_fade_begin = 60.0
	light.distance_fade_length = 15.0
	for i: int in 2:
		var lamp := MeshInstance3D.new()
		var lamp_mesh := BoxMesh.new()
		lamp_mesh.size = Vector3(0.5, 0.13, 0.28)
		var lamp_material := StandardMaterial3D.new()
		lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp_material.albedo_color = light.colors[i] * 2.2
		lamp_mesh.material = lamp_material
		lamp.mesh = lamp_mesh
		lamp.position = Vector3(-0.3 if i == 0 else 0.3, 0.01, 0.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lamp)
		light.lamps.append(lamp)
	root.add_child(light)
	return root


const BEAM_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 beam_color : source_color = vec4(0.75, 0.82, 1.0, 1.0);
uniform float strength = 0.09;
uniform float beam_length = 140.0;
varying float along;
void vertex() {
	along = clamp(VERTEX.y / beam_length + 0.5, 0.0, 1.0);
}
void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float fade = (1.0 - along) * smoothstep(0.0, 0.04, along);
	ALBEDO = beam_color.rgb * strength * edge * fade;
}
"""

## A searchlight on the horizon, its beam sweeping the low cloud.
static func searchlight(at: Vector3, length: float = 140.0, sweep_speed: float = 0.12) -> Searchlight:
	var beam_shader := Shader.new()
	beam_shader.code = BEAM_SHADER
	var light := Searchlight.new()
	light.position = at
	light.sweep_speed = sweep_speed
	var pivot := Node3D.new()
	light.add_child(pivot)
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = length * 0.06
	cone.bottom_radius = 0.6
	cone.height = length
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = beam_shader
	material.set_shader_parameter(&"beam_length", length)
	cone.material = material
	beam.mesh = cone
	beam.position = Vector3(0.0, length * 0.5, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)
	return light


## Floating motes (Echo spores, dust in a light) filling a box.
static func motes(at: Vector3, extents: Vector3, amount: int, color: Color = Color(0.27, 0.92, 1.0)) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.3
	process.gravity = Vector3(0.0, 0.1, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.7
	process.color_ramp = _ramp([[0.0, Color(color.r, color.g, color.b, 0.0)], [0.3, Color(color.r, color.g, color.b, 0.9)], [1.0, Color(color.r, color.g, color.b, 0.0)]])
	var particles := _particles(int(amount * amount_scale()), 6.0, process, 0.06, true, AABB(-extents * 1.5, extents * 3.0))
	particles.position = at
	return particles


## A patch of low mist (volumetric fog only; nothing on presets without it).
static func mist(at: Vector3, size: Vector3, density: float = 0.35, albedo: Color = Color(0.85, 0.87, 0.85), emission: Color = Color.BLACK) -> FogVolume:
	var volume := FogVolume.new()
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = size
	volume.position = at
	var material := FogMaterial.new()
	material.density = density
	material.albedo = albedo
	material.emission = emission
	material.height_falloff = 0.6
	material.edge_fade = 0.6
	volume.material = material
	return volume


## A monitor showing static (needs its own quad, so use a handful at most).
static func static_screen(at: Vector3, yaw_degrees: float, size: Vector2 = Vector2(0.52, 0.32)) -> MeshInstance3D:
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/static_screen.gdshader")
	quad.material = material
	screen.mesh = quad
	screen.position = at
	screen.rotation_degrees.y = yaw_degrees
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return screen
