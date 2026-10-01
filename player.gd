extends CharacterBody3D
## Co-op player. The owning peer moves it (WASD, face mouse, click/Space to attack);
## a MultiplayerSynchronizer copies position and rotation to everyone else.
## Animations are derived locally from movement, so they need no extra syncing.

const CHARACTERS := {
	"Knight": ["1H_Sword", "Round_Shield"],
	"Barbarian": ["1H_Axe", "Barbarian_Round_Shield"],
	"Rogue": ["Knife", "Knife_Offhand"],
	"Mage": ["1H_Wand", "Spellbook"],
}
const ATTACK_ANIM := "1H_Melee_Attack_Slice_Horizontal"

@export var speed := 6.0
@export var camera_offset := Vector3(0, 12, 7)

var character := "Knight"  # set by the spawner before the player enters the tree
var _camera: Camera3D
var _anim: AnimationPlayer
var _attacking := false
var _last_position := Vector3.ZERO


func _init() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

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


func _ready() -> void:
	var model: Node3D = load("res://assets/kaykit/adventurers/characters/%s.glb" % character).instantiate()
	model.position.y = -1.0  # capsule is centered; model origin is at its feet
	model.rotation.y = PI  # KayKit models face +Z, Godot's forward is -Z
	add_child(model)
	var gear: Array = CHARACTERS[character]
	for slot in ["handslot_r", "handslot_l"]:
		for item: Node3D in model.find_child(slot, true, false).get_children():
			item.visible = item.name in gear

	_anim = model.find_child("AnimationPlayer", true, false)
	for loop_anim in ["Idle", "Running_A"]:
		_anim.get_animation(loop_anim).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(func(_name: StringName) -> void: _attacking = false)
	_anim.play("Idle")
	_last_position = position

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

	var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not _attacking and delta > 0.0:
		_anim.play("Running_A" if moved / delta > 0.5 else "Idle", 0.15)


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
	if _attacking:
		return
	_attacking = true
	_anim.play(ATTACK_ANIM, 0.1)
