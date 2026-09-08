extends CanvasLayer

@export var heart_texture: Texture2D

@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var timer_label: Label = $TimerLabel


func _ready() -> void:
	Game.life_changed.connect(_on_life_changed)
	Game.time_changed.connect(_on_time_changed)
	Game.game_over.connect(_on_game_over)

	_on_life_changed(Game.life)
	_on_time_changed(Game.time_remaining)


func _on_life_changed(new_life: int) -> void:
	for child in hearts_container.get_children():
		child.queue_free()

	for i in range(new_life):
		var heart := TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = heart_texture.get_size()
		hearts_container.add_child(heart)


func _on_time_changed(remaining: float) -> void:
	@warning_ignore("integer_division")
	var minutes: int = int(remaining) / 60
	var seconds: int = int(remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_game_over() -> void:
	timer_label.text = "GAME OVER"
	# TODO: tela de derrota / pausar o jogo aqui
