extends CharacterBody3D
## Third-person controller: WASD move, mouse look, Space jump, Esc frees the mouse.

@export var speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

var _pivot := Node3D.new()


func _ready() -> void:
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	add_child(col)
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	add_child(body)

	_pivot.position.y = 0.6
	_pivot.rotation.x = -0.3
	add_child(_pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 4.0
	arm.add_excluded_object(get_rid())
	_pivot.add_child(arm)
	arm.add_child(Camera3D.new())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pivot.rotation.x = clampf(_pivot.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 0.4)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
