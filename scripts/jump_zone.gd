extends Area3D

## Jump tile trigger. Applies an upward impulse when the marble rolls over it.
## The impulse scales with horizontal speed so a fast marble clears more tiles.

const BASE_JUMP: float = 3.0
const SPEED_SCALE: float = 0.55
const MAX_JUMP: float = 13.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	var flat_speed := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z).length()
	var jump_v := clampf(flat_speed * SPEED_SCALE, BASE_JUMP, MAX_JUMP)
	body.linear_velocity.y = jump_v
