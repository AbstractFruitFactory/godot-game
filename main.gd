extends Node3D
## Dungeon room, lighting, co-op lobby and player spawning.
## Command line (after `--`): `--host`, `--join[=ip]`, `--screenshot[=name]`.

const PORT := 7777
const ROOM_SIZE := 20.0
const TORCH_ENERGY := 4.0
const MODELS := "res://assets/kaykit/dungeon/models/"
const PlayerScript := preload("res://player.gd")

var _players := Node3D.new()
var _next_character := 0
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
		_torches[i].light_energy = TORCH_ENERGY + sin(t * 9.0 + i) * 0.15 + sin(t * 23.0 + i * 2.0) * 0.1


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
	_spawner.spawn({"id": id, "character": _next_character})
	_next_character += 1


func _remove_player(id: int) -> void:
	var player := _players.get_node_or_null(str(id))
	if player:
		player.queue_free()


func _create_player(data: Dictionary) -> Node:
	var player: CharacterBody3D = PlayerScript.new()
	player.name = str(data.id)
	player.character = PlayerScript.CHARACTERS.keys()[data.character % PlayerScript.CHARACTERS.size()]
	player.position = Vector3(data.character * 1.5 - 1.5, 1, 4)
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
	for x in range(-8, 9, 4):
		for z in range(-8, 9, 4):
			_place("floor_tile_large", Vector3(x, 0, z))
		_place("wall_doorway" if x == 0 else "wall", Vector3(x, 0, -h))
	for z in range(-8, 9, 4):
		_place("wall", Vector3(-h, 0, z), PI / 2)
		_place("wall", Vector3(h, 0, z), PI / 2)
	_place("pillar", Vector3(-h, 0, -h))
	_place("pillar", Vector3(h, 0, -h))

	# Walls and floor collide via plain boxes. The south side has no visible wall so the camera can see in.
	_add_collider(Vector3(ROOM_SIZE, 0.5, ROOM_SIZE), Vector3(0, -0.25, 0))
	_add_collider(Vector3(ROOM_SIZE, 4, 1), Vector3(0, 2, -h))
	_add_collider(Vector3(ROOM_SIZE, 4, 1), Vector3(0, 2, h))
	_add_collider(Vector3(1, 4, ROOM_SIZE), Vector3(-h, 2, 0))
	_add_collider(Vector3(1, 4, ROOM_SIZE), Vector3(h, 2, 0))

	for x in [-5.0, 5.0]:
		for z in [-4.0, 4.0]:
			_place("pillar", Vector3(x, 0, z))
			_add_collider(Vector3(1.5, 4, 1.5), Vector3(x, 2, z))
	for prop: Array in [["barrel_large", Vector3(-8, 0, -8)], ["crates_stacked", Vector3(8, 0, -8)],
			["chest", Vector3(-8, 0, 7)], ["barrel_small_stack", Vector3(8, 0, 7)]]:
		_place(prop[0], prop[1])
		_add_collider(Vector3(1.8, 2, 1.8), prop[1] + Vector3(0, 1, 0))

	for x in [-4.0, 4.0]:
		_add_torch(Vector3(x, 2, -h + 0.5), 0.0)
	for z in [-4.0, 4.0]:
		_add_torch(Vector3(-h + 0.5, 2, z), PI / 2)
		_add_torch(Vector3(h - 0.5, 2, z), -PI / 2)


func _place(model: String, pos: Vector3, rot_y := 0.0) -> void:
	var path := MODELS + model + ".gltf.glb"
	if not ResourceLoader.exists(path):
		path = MODELS + model + ".glb"
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.rotation.y = rot_y
	add_child(node)


func _add_collider(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(col)
	add_child(body)


## Wall torch at `pos` (on the wall's inner face), facing into the room along `rot_y`.
func _add_torch(pos: Vector3, rot_y: float) -> void:
	_place("torch_mounted", pos, rot_y)
	var flame_pos := pos + Basis(Vector3.UP, rot_y) * Vector3(0, 0.55, 0.35)
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.6, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.15)
	mat.emission_energy_multiplier = 4.0
	var flame := MeshInstance3D.new()
	flame.mesh = mesh
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = flame_pos
	add_child(flame)

	var light := OmniLight3D.new()
	light.position = flame_pos + Basis(Vector3.UP, rot_y) * Vector3(0, 0, 0.2)
	light.light_color = Color(1, 0.6, 0.3)
	light.omni_range = 12.0
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
