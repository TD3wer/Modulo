extends Node2D

## Velocidade de deslocamento ao longo do Path2D (em "progress" units/seg,
## que no Godot 4 equivale aproximadamente a pixels por segundo na curva)
@export var speed: float = 30.0
@export var max_health: int = 30

var health: int
var path_follow: PathFollow2D
var is_dead: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	health = max_health
	# O inimigo sempre nasce como filho de um PathFollow2D (o spawner cuida disso)
	path_follow = get_parent() as PathFollow2D
	add_to_group("enemies")
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead or path_follow == null:
		return

	path_follow.progress += speed * delta

	# Chegou no fim do caminho (ainda sem sistema de "vida do jogador", só remove por enquanto)
	if path_follow.progress_ratio >= 1.0:
		_reach_end()


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	remove_from_group("enemies")

	if anim.sprite_frames and anim.sprite_frames.has_animation("die"):
		anim.play("die")
		await anim.animation_finished

	# Remove o PathFollow2D inteiro, o que remove o inimigo junto
	if is_instance_valid(path_follow):
		path_follow.queue_free()


func _reach_end() -> void:
	is_dead = true
	if is_instance_valid(path_follow):
		path_follow.queue_free()
	Game.take_life(1)
	Game.shake_screen()
