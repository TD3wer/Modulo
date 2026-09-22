extends Node2D

@export var fire_rate: float = 1.0  # tiros por segundo
@export var damage: int = 10
@export var bullet_scene: PackedScene
@export var is_preview: bool = false  # true = fantasma seguindo o mouse durante o arraste

@export_group("Habilidade: Tiro Rápido")
@export var ability_charge_time: float = 30.0
@export var ability_duration: float = 8.0
@export var ability_fire_rate_multiplier: float = 2.0
@export var ability_animation_fps_boost: float = 4.0  # quanto mais rápido a animação de tiro fica

@export_group("Remoção")
@export var remove_cooldown: float = 15.0  # segundos até o ícone dessa torre liberar de novo no rádio

@export_group("Som")
@export var shoot_sound: AudioStream
@export var shoot_pitch_min: float = 0.9
@export var shoot_pitch_max: float = 1.1

signal removed(placed_cell: Vector2i, tower_scene: PackedScene, cooldown: float)

enum State { DROPPING, IDLE, SHOOTING }

var state: State = State.DROPPING
var enemies_in_range: Array[Node2D] = []

var ability_charge: float = 0.0
var ability_ready: bool = false
var ability_active: bool = false

var placed_cell: Vector2i  # setado de fora (pelo PlacementManager) na hora que é colocada
var tower_scene_ref: PackedScene  # idem — pra saber qual ícone reativar quando remover

var _hovering_tower: bool = false
var _hovering_remove_button: bool = false
var _show_range: bool = false
var _hover_hide_request_id: int = 0  # invalida pedidos de "esconder" antigos quando o mouse volta

@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/Shape
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")  # opcional
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var click_area: Area2D = $ClickArea
@onready var remove_button: TextureButton = $RemoveButton
@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio


func _ready() -> void:
	if is_preview:
		anim.play("idle")
		anim.pause()  # trava num frame só, fica inerte enquanto é carregado
		# TODO: quando tiver uma animação de "sendo helidropado", troca aqui
		return

	print("Recruta: ability_charge_time = ", ability_charge_time, " | ability_duration = ", ability_duration)

	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_tower_mouse_entered)
	click_area.mouse_exited.connect(_on_tower_mouse_exited)

	remove_button.visible = false
	remove_button.pressed.connect(_on_remove_button_pressed)
	remove_button.mouse_entered.connect(_on_remove_button_mouse_entered)
	remove_button.mouse_exited.connect(_on_remove_button_mouse_exited)

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


func _process(delta: float) -> void:
	if is_preview or state == State.DROPPING:
		return

	var target := _get_target()
	if target:
		_face_target(target)

	_update_ability_charge(delta)


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

	_play_shoot_sound()


func _play_shoot_sound() -> void:
	if shoot_sound == null:
		return
	shoot_audio.stream = shoot_sound
	shoot_audio.pitch_scale = randf_range(shoot_pitch_min, shoot_pitch_max)
	shoot_audio.play()


func _face_target(target: Node2D) -> void:
	# sprite olha pra direita por padrão; inverte só quando o alvo tá à esquerda
	var facing_left: bool = target.global_position.x < global_position.x
	anim.flip_h = facing_left

	# se tiver Muzzle, espelha o x dele também, senão a bala nasce sempre do lado direito
	if muzzle:
		muzzle.position.x = -abs(muzzle.position.x) if facing_left else abs(muzzle.position.x)


func _update_ability_charge(delta: float) -> void:
	if ability_active or ability_ready:
		return  # já em uso ou já pronta esperando clique, não carrega mais

	ability_charge += delta
	if ability_charge >= ability_charge_time:
		ability_charge = ability_charge_time
		ability_ready = true
		anim.modulate = Color(0.4, 1.0, 1.0)  # tint ciano: "pronta, clica em mim"


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_activate_ability()


func _on_tower_mouse_entered() -> void:
	_hovering_tower = true
	_update_hover_visuals()


func _on_tower_mouse_exited() -> void:
	_hovering_tower = false
	_update_hover_visuals()


func _on_remove_button_mouse_entered() -> void:
	_hovering_remove_button = true
	_update_hover_visuals()


func _on_remove_button_mouse_exited() -> void:
	_hovering_remove_button = false
	_update_hover_visuals()


## Ganhar hover mostra na hora. Perder hover NÃO esconde na hora — espera
## 1s (coyote time) pra dar tempo do mouse atravessar o vão entre a torre
## e o botão. Se o mouse voltar (pra torre OU pro botão) antes desse
## segundo passar, o esconder é cancelado.
func _update_hover_visuals() -> void:
	var hovering: bool = _hovering_tower or _hovering_remove_button
	_hover_hide_request_id += 1  # qualquer mudança de estado invalida um esconder pendente antigo

	if hovering:
		_show_range = true
		queue_redraw()
		remove_button.visible = true
	else:
		_request_hide_after_delay(_hover_hide_request_id)


func _request_hide_after_delay(request_id: int) -> void:
	await get_tree().create_timer(0.10, false).timeout

	# se o mouse voltou nesse meio tempo, um request mais novo já rodou —
	# esse aqui tá desatualizado, não faz nada
	if request_id != _hover_hide_request_id:
		return

	_show_range = false
	queue_redraw()
	remove_button.visible = false


func _draw() -> void:
	if not _show_range or range_shape == null:
		return
	var shape := range_shape.shape
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		draw_circle(range_shape.position, radius, Color(0.4, 1.0, 1.0, 0.35), true, -1.0, false)
	else:
		push_warning("Recruta: RangeArea/CollisionShape2D não tem um CircleShape2D atribuído (shape = %s). O círculo de alcance não aparece sem isso." % shape)


func _on_remove_button_pressed() -> void:
	removed.emit(placed_cell, tower_scene_ref, remove_cooldown)
	queue_free()


func _try_activate_ability() -> void:
	if not ability_ready or ability_active:
		return

	ability_ready = false
	ability_active = true
	ability_charge = 0.0
	anim.modulate = Color(1.0, 0.4, 0.4, 0.7)  # mesmo vermelho do preview de célula inválida no drag

	var boosted_wait_time: float = (1.0 / max(fire_rate, 0.01)) / ability_fire_rate_multiplier
	fire_timer.wait_time = boosted_wait_time
	fire_timer.start()  # reinicia o ciclo do zero — só trocar wait_time deixa sobra do intervalo antigo rodando

	_on_fire_timer_timeout()  # atira agora, não espera o próximo tick do timer
	_set_shoot_animation_boost(true)

	await get_tree().create_timer(ability_duration, false).timeout  # false = pausa junto com o resto do jogo

	ability_active = false
	fire_timer.wait_time = 1.0 / max(fire_rate, 0.01)
	fire_timer.start()
	anim.modulate = Color.WHITE
	_set_shoot_animation_boost(false)


## speed_scale é por INSTÂNCIA do AnimatedSprite2D — diferente de mexer
## direto no SpriteFrames, que geralmente é um recurso compartilhado
## entre todos os Recrutas (mudar ali afetaria todo mundo de uma vez).
func _set_shoot_animation_boost(active: bool) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation("shoot"):
		return

	var base_fps: float = anim.sprite_frames.get_animation_speed("shoot")
	if active and base_fps > 0.0:
		anim.speed_scale = (base_fps + ability_animation_fps_boost) / base_fps
	else:
		anim.speed_scale = 1.0
