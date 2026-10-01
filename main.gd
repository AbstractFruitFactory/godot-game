extends Node3D
## Builds the test world in code: lighting, ground, trees, player.

const KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S,
	"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
}

func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_world()
	var player: CharacterBody3D = preload("res://player.gd").new()
	player.position = Vector3(0, 1, 0)
	add_child(player)
	if "--screenshot" in OS.get_cmdline_user_args():
		_screenshot_and_quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_save_screenshot()


func _setup_input() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.75)
	sky_mat.sky_horizon_color = Color(0.95, 0.72, 0.55)
	sky_mat.ground_horizon_color = Color(0.95, 0.72, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.95, 0.85, 0.75)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.85, 0.65)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-25, -40, 0)
	add_child(sun)


func _build_world() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(100, 100)
	_add_prop(ground, Color(0.35, 0.5, 0.25), Vector3.ZERO)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 40:
		var angle := rng.randf() * TAU
		var pos := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(6, 45)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.2
		trunk.bottom_radius = 0.25
		trunk.height = 2.0
		_add_prop(trunk, Color(0.4, 0.27, 0.18), pos + Vector3(0, 1, 0))
		var leaves := CylinderMesh.new()
		leaves.top_radius = 0.0
		leaves.bottom_radius = 1.2
		leaves.height = 3.0
		_add_prop(leaves, Color(0.2, 0.4, 0.2), pos + Vector3(0, 3.5, 0))


func _add_prop(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)


func _save_screenshot() -> void:
	var path := ProjectSettings.globalize_path("res://screenshots/latest.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot saved: ", path)


func _screenshot_and_quit() -> void:
	for i in 60:  # let fog, SSAO and shadows settle
		await get_tree().process_frame
	_save_screenshot()
	get_tree().quit()
