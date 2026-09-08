extends Node2D

## Arrasta aqui a DialogueBox instanciada dentro dessa cena.
@export var dialogue_box: Control

## --- Animação do personagem, por linha (mesmo esquema de antes) ---
@export var character_sprite: AnimatedSprite2D
@export var dialogue_animations: Array[String] = [
	"talk_calm",
	"talk_angry",
	"slam_table",
]
@export var dialogue_talk_durations: Array[float] = [
	1.5,
	1.5,
	0.0,
]
var _talk_timer: Timer

## --- Alerta (TileMapLayer separada), aparece a partir dessa linha ---
@export var alert_trigger_line: int = 1
@export var alert_layer: TileMapLayer

## --- Cena de destino quando o diálogo terminar ---
@export var next_scene: PackedScene

func _ready() -> void:
	_talk_timer = Timer.new()
	_talk_timer.one_shot = true
	add_child(_talk_timer)
	_talk_timer.timeout.connect(_on_talk_timer_timeout)

	if alert_layer != null:
		alert_layer.visible = false

	if dialogue_box == null:
		push_warning("CutsceneController: arrasta a DialogueBox no campo do Inspector.")
		return

	# Esse é o único lugar que "conhece" a DialogueBox por dentro — ela
	# não sabe nada sobre a gente, só avisa quando algo acontece.
	dialogue_box.line_shown.connect(_on_line_shown)
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	dialogue_box.start_dialogue()

func _on_line_shown(index: int, _line_text: String) -> void:
	_play_animation_for_line(index)
	_update_alert_visibility(index)

func _play_animation_for_line(index: int) -> void:
	if character_sprite == null:
		return
	if index >= dialogue_animations.size():
		return

	var anim_name: String = dialogue_animations[index]
	if anim_name == "":
		return

	if not character_sprite.sprite_frames.has_animation(anim_name):
		push_warning("Animação '%s' não encontrada no SpriteFrames." % anim_name)
		return

	_talk_timer.stop()
	character_sprite.play(anim_name)

	var duration: float = 0.0
	if index < dialogue_talk_durations.size():
		duration = dialogue_talk_durations[index]

	if duration > 0.0:
		_talk_timer.start(duration)

func _on_talk_timer_timeout() -> void:
	character_sprite.stop()
	character_sprite.frame = 0

func _update_alert_visibility(index: int) -> void:
	if alert_layer == null:
		return
	alert_layer.visible = index >= alert_trigger_line

func _on_dialogue_finished() -> void:
	if next_scene != null:
		get_tree().change_scene_to_packed(next_scene)
