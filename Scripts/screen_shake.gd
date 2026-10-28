extends Node

## Deixa vazio pra sacudir o próprio PAI desse node automaticamente.
## Só preenche se quiser sacudir outra coisa específica (ex: uma câmera
## que não é o pai direto dele).
@export var target: Node2D

var _shake_time_left: float = 0.0
var _shake_strength: float = 0.0
var _original_position: Vector2
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if target == null:
		target = get_parent() as Node2D

	if target:
		_original_position = target.position

	Game.screen_shake.connect(_on_screen_shake)


func _on_screen_shake(duration: float, strength: float) -> void:
	_shake_time_left = duration
	_shake_strength = strength


func _process(delta: float) -> void:
	if target == null:
		return

	if _shake_time_left > 0.0:
		_shake_time_left -= delta
		target.position = _original_position + Vector2(
			_rng.randf_range(-_shake_strength, _shake_strength),
			_rng.randf_range(-_shake_strength, _shake_strength)
		)
	elif target.position != _original_position:
		target.position = _original_position  # garante que volta exatamente pro lugar certo
