extends CharacterBody3D
## Co-op player. The owning peer moves it (WASD, face mouse, click/Space to attack);
## a MultiplayerSynchronizer copies position and rotation to everyone else.

@export var speed := 6.0
@export var camera_offset := Vector3(0, 12, 7)

var _sword_pivot := Node3D.new()
var _camera: Camera3D
var _swinging := false


func _init() -> void:
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	add_child(col)
	var mat := StandardMaterial3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = CapsuleMesh.new()
	body.material_override = mat
	add_child(body)

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.1, 0.1, 1.2)
	var blade := MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.position = Vector3(0, 0, -0.9)
	_sword_pivot.position.y = 0.2
	_sword_pivot.rotation.y = deg_to_rad(60)
	_sword_pivot.add_child(blade)
	add_child(_sword_pivot)

	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	add_child(sync)


# Authority must be set here (not in _ready) so the synchronizer is owned correctly at spawn.
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	var mat: StandardMaterial3D = $Body.material_override
	mat.albedo_color = Color.from_hsv(fmod(name.to_int() * 0.618, 1.0), 0.5, 0.9)


func _ready() -> void:
	if is_multiplayer_authority():
		_camera = Camera3D.new()
		_camera.top_level = true
		add_child(_camera)
		_camera.global_position = global_position + camera_offset
		_camera.look_at(global_position)
		_camera.current = true


func _process(delta: float) -> void:
	if _camera:
		var target := global_position + camera_offset
		_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-8.0 * delta))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity.x = input.x * speed
	velocity.z = input.y * speed
	move_and_slide()
	_face_mouse()
	if Input.is_action_just_pressed("attack"):
		attack.rpc()


func _face_mouse() -> void:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(origin, dir)
	if hit == null:
		return
	var target := Vector3(hit.x, global_position.y, hit.z)
	if target.distance_to(global_position) > 0.1:
		look_at(target)


@rpc("authority", "call_local", "reliable")
func attack() -> void:
	if _swinging:
		return
	_swinging = true
	var tween := create_tween()
	tween.tween_property(_sword_pivot, "rotation:y", deg_to_rad(-80), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sword_pivot, "rotation:y", deg_to_rad(60), 0.25)
	tween.tween_callback(func() -> void: _swinging = false)
