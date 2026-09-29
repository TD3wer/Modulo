extends Node

signal life_changed(new_life: int)
signal game_over
signal time_changed(remaining: float)
signal time_up
signal screen_shake(duration: float, strength: float)

@export var cursor_normal: Texture2D
@export var cursor_grab: Texture2D  # usado enquanto o botão do mouse tá pressionado
@export var cursor_scale: int = 4  # multiplicador de tamanho (nearest-neighbor, sem borrar)

const MAX_LIFE: int = 5
const STAGE_DURATION: float = 180.0  # 3 minutos

var life: int = MAX_LIFE
var time_remaining: float = STAGE_DURATION
var chosen_gender: String = ""  # "masc" ou "fem" — setado na tela de seleção da intro

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


func shake_screen(duration: float = 0.25, strength: float = 3.0) -> void:
	screen_shake.emit(duration, strength)
