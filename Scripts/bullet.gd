extends Node2D

@export var speed: float = 300.0

var target: Node2D = null
var damage: int = 10


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var direction: Vector2 = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()  # gira a bala pra "apontar" na direção do voo

	if global_position.distance_to(target.global_position) < 6.0:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
