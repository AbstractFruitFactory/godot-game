extends Node3D
## Dungeon room, lighting, co-op lobby and player spawning.
## Command line (after `--`): `--host`, `--join[=ip]`, `--screenshot[=name]`.

const PORT := 7777
const ROOM_SIZE := 20.0
const WALL_COLOR := Color(0.35, 0.33, 0.32)
const PlayerScript := preload("res://player.gd")

var _players := Node3D.new()
var _spawner := MultiplayerSpawner.new()
var _torches: Array[OmniLight3D] = []
var _menu := CanvasLayer.new()


func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_room()
	_players.name = "Players"
	add_child(_players)
	_spawner.name = "PlayerSpawner"
	_spawner.spawn_function = _create_player
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Players")
	_build_menu()
	_handle_cmdline()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _torches.size():
		_torches[i].light_energy = 5.0 + sin(t * 9.0 + i) * 0.15 + sin(t * 23.0 + i * 2.0) * 0.1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_save_screenshot("latest")


# --- Networking ---

func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Could not host on port %d: %s" % [PORT, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(1)
	_menu.hide()


func join(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Could not join %s: %s" % [ip, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(_on_server_lost)
	_menu.hide()


func _add_player(id: int) -> void:
	_spawner.spawn(id)


func _remove_player(id: int) -> void:
	var player := _players.get_node_or_null(str(id))
	if player:
		player.queue_free()


func _create_player(id: int) -> Node:
	var player: CharacterBody3D = PlayerScript.new()
	player.name = str(id)
	player.position = Vector3(_players.get_child_count() * 1.5 - 1.5, 1, 4)
	return player


func _on_server_lost() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().reload_current_scene()


# --- Setup ---

func _setup_input() -> void:
	var keys := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "attack": KEY_SPACE}
	for action: String in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		_add_action(action, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add_action("attack", click)


func _add_action(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, ev)


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	var ip_input := LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(200, 0)
	var host_btn := Button.new()
	host_btn.text = "Host"
	host_btn.pressed.connect(host)
	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(func() -> void: join(ip_input.text))
	box.add_child(host_btn)
	box.add_child(ip_input)
	box.add_child(join_btn)
	_menu.add_child(box)
	add_child(_menu)


func _handle_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1) if "=" in arg else ""
		if arg == "--host":
			host()
		elif arg.begins_with("--join"):
			join(value if value else "127.0.0.1")
		elif arg.begins_with("--screenshot"):
			_screenshot_and_quit(value if value else "latest")


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.45)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_room() -> void:
	var h := ROOM_SIZE / 2
	_add_box(Vector3(ROOM_SIZE, 0.5, ROOM_SIZE), Vector3(0, -0.25, 0), Color(0.3, 0.28, 0.26))
	_add_box(Vector3(ROOM_SIZE, 3, 1), Vector3(0, 1.5, -h), WALL_COLOR)
	_add_box(Vector3(1, 3, ROOM_SIZE), Vector3(-h, 1.5, 0), WALL_COLOR)
	_add_box(Vector3(1, 3, ROOM_SIZE), Vector3(h, 1.5, 0), WALL_COLOR)
	# South wall stays low so the camera can see into the room.
	_add_box(Vector3(ROOM_SIZE, 0.6, 1), Vector3(0, 0.3, h), WALL_COLOR)
	for x in [-5.0, 5.0]:
		for z in [-4.0, 4.0]:
			_add_box(Vector3(1, 3, 1), Vector3(x, 1.5, z), WALL_COLOR)
	for pos in [Vector3(-6, 2, -h + 0.7), Vector3(6, 2, -h + 0.7), Vector3(-h + 0.7, 2, 0), Vector3(h - 0.7, 2, 0)]:
		_add_torch(pos)
	_add_torch(Vector3(0, 1.2, 0))  # brazier in the middle


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(inst)
	body.add_child(col)
	add_child(body)


func _add_torch(pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.6, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.15)
	mat.emission_energy_multiplier = 4.0
	var flame := MeshInstance3D.new()
	flame.mesh = mesh
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = pos
	add_child(flame)

	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1, 0.6, 0.3)
	light.omni_range = 14.0
	light.shadow_enabled = true
	add_child(light)
	_torches.append(light)


# --- Screenshots ---

func _save_screenshot(file_name: String) -> void:
	var path := ProjectSettings.globalize_path("res://screenshots/%s.png" % file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot saved: ", path)


func _screenshot_and_quit(file_name: String) -> void:
	for i in 180:  # let networking connect and fog, SSAO and shadows settle
		await get_tree().process_frame
	_save_screenshot(file_name)
	get_tree().quit()
