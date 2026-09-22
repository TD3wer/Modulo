extends Node

signal life_changed(new_life: int)
signal game_over
signal time_changed(remaining: float)
signal time_up
signal screen_shake(duration: float, strength: float)

const MAX_LIFE: int = 5
const STAGE_DURATION: float = 180.0  # 3 minutos

var life: int = MAX_LIFE
var time_remaining: float = STAGE_DURATION

var _timer_running: bool = false


func _process(delta: float) -> void:
	if not _timer_running:
		return

	time_remaining = max(time_remaining - delta, 0.0)
	time_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		_timer_running = false
		time_up.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_fullscreen()


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
