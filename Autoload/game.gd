extends Node

signal life_changed(new_life: int)
signal game_over
signal time_changed(remaining: float)
signal time_up
signal screen_shake(duration: float, strength: float)
signal morale_changed(new_morale: int)

@export var cursor_normal: Texture2D
@export var cursor_grab: Texture2D  # usado enquanto o botão do mouse tá pressionado
@export var cursor_scale: int = 4  # multiplicador de tamanho (nearest-neighbor, sem borrar)

const MAX_LIFE: int = 5
const STAGE_DURATION: float = 180.0  # 3 minutos

var life: int = MAX_LIFE
var time_remaining: float = STAGE_DURATION
var chosen_gender: String = ""  # "masc" ou "fem" — setado na tela de seleção da intro

## Moral: a "moeda" pra colocar torres. Inimigos derrotados dão moral,
## torres custam moral. Zera a cada fase (ver begin_stage).
var morale: int = 0
## A primeira torre de cada fase é grátis, independente do custo.
var free_tower_available: bool = true

var _timer_running: bool = false
var _cursor_normal_scaled: Texture2D
var _cursor_grab_scaled: Texture2D


func _ready() -> void:
	_cursor_normal_scaled = _scaled_cursor(cursor_normal)
	_cursor_grab_scaled = _scaled_cursor(cursor_grab)
	Input.set_custom_mouse_cursor(_cursor_normal_scaled)


func _process(delta: float) -> void:
	if not _timer_running:
		return

	time_remaining = max(time_remaining - delta, 0.0)
	time_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		_timer_running = false
		time_up.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_fullscreen()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_custom_mouse_cursor(_cursor_grab_scaled if event.pressed else _cursor_normal_scaled)


func _scaled_cursor(tex: Texture2D) -> Texture2D:
	if tex == null or cursor_scale <= 1:
		return tex
	var img: Image = tex.get_image()
	img.resize(img.get_width() * cursor_scale, img.get_height() * cursor_scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func start_stage_timer() -> void:
	_timer_running = true


func stop_stage_timer() -> void:
	_timer_running = false


func take_life(amount: int = 1) -> void:
	life = max(life - amount, 0)
	life_changed.emit(life)

	if life <= 0:
		_timer_running = false
		game_over.emit()


func reset() -> void:
	life = MAX_LIFE
	time_remaining = STAGE_DURATION
	_timer_running = false
	begin_stage()


## Chamado no começo de cada fase: moral zerada e a primeira torre volta a ser grátis.
func begin_stage() -> void:
	morale = 0
	free_tower_available = true
	morale_changed.emit(morale)


func add_morale(amount: int) -> void:
	morale += amount
	morale_changed.emit(morale)


## Dá pra colocar uma torre com esse custo agora? (a primeira da fase é sempre grátis)
func can_afford(cost: int) -> bool:
	return free_tower_available or morale >= cost


## Tenta pagar uma torre. Devolve false (sem cobrar nada) se não der.
func spend_for_tower(cost: int) -> bool:
	if free_tower_available:
		free_tower_available = false
		# a moral não mudou, mas o ESTADO mudou (acabou a grátis) — avisa quem escuta
		morale_changed.emit(morale)
		return true

	if morale < cost:
		return false

	morale -= cost
	morale_changed.emit(morale)
	return true


func shake_screen(duration: float = 0.25, strength: float = 3.0) -> void:
	screen_shake.emit(duration, strength)
