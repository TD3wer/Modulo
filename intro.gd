extends CanvasLayer

enum Phase { SELECT, QUOTE, DATE }

## Pra onde vai depois que o jogador confirma a data (hoje: Cutscene 1).
@export var next_scene: PackedScene

@export_group("Fase 2: Frase tema")
@export_multiline var theme_quote: String = "[b]O que a você chama de [shake]escolha[/shake], quando a alternativa é [shake]morrer de um jeito ou de outro?[/shake][/b]"

@export_group("Fase 3: Data/hora/local")
@export_multiline var date_text: String = "09 Jan. 0292 a.r"

@onready var quote_phase: Control = $QuotePhase
@onready var quote_label: RichTextLabel = $QuotePhase/TypewriterLabel

@onready var select_phase: Control = $CharacterSelectPhase
@onready var male_option: Control = $CharacterSelectPhase/MaleOption
@onready var male_anim: AnimatedSprite2D = $CharacterSelectPhase/MaleOption/AnimatedSprite2D
@onready var female_option: Control = $CharacterSelectPhase/FemaleOption
@onready var female_anim: AnimatedSprite2D = $CharacterSelectPhase/FemaleOption/AnimatedSprite2D

@onready var date_phase: Control = $DatePhase
@onready var date_label: RichTextLabel = $DatePhase/TypewriterLabel

var phase: Phase = Phase.SELECT


func _ready() -> void:
	# Sem isso, esses Control (tela inteira) absorvem o clique antes dele
	# chegar nas Area2D dos personagens, que ficam "por baixo" deles.
	select_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE

	select_phase.visible = true
	quote_phase.visible = false
	date_phase.visible = false

	male_option.mouse_entered.connect(func(): male_anim.play("hover"))
	male_option.mouse_exited.connect(func(): male_anim.play("idle"))
	male_option.gui_input.connect(_on_male_gui_input)

	female_option.mouse_entered.connect(func(): female_anim.play("hover"))
	female_option.mouse_exited.connect(func(): female_anim.play("idle"))
	female_option.gui_input.connect(_on_female_gui_input)

	male_anim.play("idle")
	female_anim.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	match phase:
		Phase.QUOTE:
			if quote_label.is_typing():
				quote_label.skip_to_end()
			else:
				_start_date_phase()
		Phase.DATE:
			if date_label.is_typing():
				date_label.skip_to_end()
			else:
				_go_to_next_scene()


func _on_male_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character("masc")


func _on_female_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character("fem")


func _select_character(gender: String) -> void:
	if phase != Phase.SELECT:
		return
	Game.chosen_gender = gender
	_start_quote_phase()


func _start_quote_phase() -> void:
	phase = Phase.QUOTE
	select_phase.visible = false
	quote_phase.visible = true
	quote_label.type_text(theme_quote)


func _start_date_phase() -> void:
	phase = Phase.DATE
	quote_phase.visible = false
	date_phase.visible = true
	date_label.type_text(date_text)


func _go_to_next_scene() -> void:
	if next_scene == null:
		push_warning("Intro: 'Next Scene' não configurado no Inspector.")
		return
	get_tree().change_scene_to_packed(next_scene)
