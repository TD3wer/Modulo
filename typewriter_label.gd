extends RichTextLabel

signal typing_finished

@export var seconds_per_character: float = 0.06
@export var typing_sound: AudioStream
@export var pitch_min: float = 0.9
@export var pitch_max: float = 1.1

@onready var _audio: AudioStreamPlayer = $TypeAudio

var _tween: Tween


func _ready() -> void:
	bbcode_enabled = true


## Começa a digitar um texto novo do zero (mata qualquer digitação em andamento).
func type_text(new_text: String) -> void:
	if _tween:
		_tween.kill()

	text = new_text
	visible_ratio = 0.0

	var total_chars: int = get_total_character_count()
	var duration: float = total_chars * seconds_per_character

	_tween = create_tween()
	_tween.tween_method(_on_progress, 0.0, 1.0, duration)
	_tween.finished.connect(_on_typing_finished)


func is_typing() -> bool:
	return _tween != null and _tween.is_running()


## Completa o texto na hora (ex: jogador apertou Enter no meio da digitação).
func skip_to_end() -> void:
	if _tween:
		_tween.kill()
	visible_ratio = 1.0
	_on_typing_finished()


func _on_progress(ratio: float) -> void:
	var previous_visible: int = get_visible_characters()
	visible_ratio = ratio
	# só toca o som quando uma letra NOVA realmente apareceu (não a cada frame)
	if get_visible_characters() > previous_visible and typing_sound:
		_audio.stream = typing_sound
		_audio.pitch_scale = randf_range(pitch_min, pitch_max)
		_audio.play()


func _on_typing_finished() -> void:
	typing_finished.emit()
