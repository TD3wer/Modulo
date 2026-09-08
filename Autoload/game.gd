extends Node

signal life_changed(new_life: int)
signal game_over
signal time_changed(remaining: float)
signal time_up

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
