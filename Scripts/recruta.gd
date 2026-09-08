extends Node2D

@export var fire_rate: float = 1.0  # tiros por segundo
@export var damage: int = 10
@export var bullet_scene: PackedScene
@export var is_preview: bool = false  # true = fantasma seguindo o mouse durante o arraste

enum State { DROPPING, IDLE, SHOOTING }

var state: State = State.DROPPING
var enemies_in_range: Array[Node2D] = []

@onready var range_area: Area2D = $RangeArea
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")  # opcional
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if is_preview:
		anim.play("idle")
		anim.pause()  # trava num frame só, fica inerte enquanto é carregado
		# TODO: quando tiver uma animação de "sendo helidropado", troca aqui
		return

	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)

	fire_timer.wait_time = 1.0 / max(fire_rate, 0.01)
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.start()

	anim.animation_finished.connect(_on_animation_finished)
	anim.play("drop")  # animação de "sendo colocado" assim que nasce


func _on_animation_finished() -> void:
	# tanto o drop quanto o shoot terminam voltando pro idle
	if state == State.DROPPING or state == State.SHOOTING:
		_enter_idle()


func _enter_idle() -> void:
	state = State.IDLE
	anim.play("idle")


func _process(_delta: float) -> void:
	if is_preview or state == State.DROPPING:
		return

	var target := _get_target()
	if target:
		_face_target(target)


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent() as Node2D
	if enemy and enemy.is_in_group("enemies") and not enemies_in_range.has(enemy):
		enemies_in_range.append(enemy)


func _on_area_exited(area: Area2D) -> void:
	var enemy := area.get_parent() as Node2D
	enemies_in_range.erase(enemy)


func _get_target() -> Node2D:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		return null
	return enemies_in_range[0]


func _on_fire_timer_timeout() -> void:
	if state == State.DROPPING:
		return  # ainda sendo colocado, não atira nesse meio tempo

	var target := _get_target()
	if target == null or bullet_scene == null:
		return

	_face_target(target)

	state = State.SHOOTING
	anim.play("shoot")

	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position if muzzle else global_position
	bullet.target = target
	bullet.damage = damage


func _face_target(target: Node2D) -> void:
	# sprite olha pra direita por padrão; inverte só quando o alvo tá à esquerda
	var facing_left: bool = target.global_position.x < global_position.x
	anim.flip_h = facing_left

	# se tiver Muzzle, espelha o x dele também, senão a bala nasce sempre do lado direito
	if muzzle:
		muzzle.position.x = -abs(muzzle.position.x) if facing_left else abs(muzzle.position.x)
