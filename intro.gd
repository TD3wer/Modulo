extends CanvasLayer

enum Phase { QUOTE, SELECT, DATE }

## Pra onde vai depois que o jogador confirma a data (hoje: Cutscene 1).
@export var next_scene: PackedScene

@export_group("Fase 1: Frase tema")
@export_multiline var theme_quote: String = "[b]O que a você chama de [shake]escolha[/shake], quando a alternativa é [shake]morrer de um jeito ou de outro?[/shake][/b]"

@export_group("Fase 3: Data/hora/local")
@export_multiline var date_text: String = "09 Jan. 0292 a.r"

@onready var quote_phase: Control = $QuotePhase
@onready var quote_label: RichTextLabel = $QuotePhase/TypewriterLabel

@onready var select_phase: Control = $CharacterSelectPhase
@onready var male_anim: AnimatedSprite2D = $CharacterSelectPhase/MaleOption/AnimatedSprite2D
@onready var male_click_area: Area2D = $CharacterSelectPhase/MaleOption/ClickArea
@onready var female_anim: AnimatedSprite2D = $CharacterSelectPhase/FemaleOption/AnimatedSprite2D
@onready var female_click_area: Area2D = $CharacterSelectPhase/FemaleOption/ClickArea

@onready var date_phase: Control = $DatePhase
@onready var date_label: RichTextLabel = $DatePhase/TypewriterLabel

var phase: Phase = Phase.QUOTE


func _ready() -> void:
	quote_phase.visible = true
	select_phase.visible = false
	date_phase.visible = false

	male_click_area.mouse_entered.connect(func(): male_anim.play("hover"))
	male_click_area.mouse_exited.connect(func(): male_anim.play("idle"))
	male_click_area.input_event.connect(_on_male_input_event)

	female_click_area.mouse_entered.connect(func(): female_anim.play("hover"))
	female_click_area.mouse_exited.connect(func(): female_anim.play("idle"))
	female_click_area.input_event.connect(_on_female_input_event)

	male_anim.play("idle")
	female_anim.play("idle")

	quote_label.type_text(theme_quote)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	match phase:
		Phase.QUOTE:
			if quote_label.is_typing():
				quote_label.skip_to_end()
			else:
				_start_select_phase()
		Phase.DATE:
			if date_label.is_typing():
				date_label.skip_to_end()
			else:
				_go_to_next_scene()


func _start_select_phase() -> void:
	phase = Phase.SELECT
	quote_phase.visible = false
	select_phase.visible = true


func _on_male_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character("masc")


func _on_female_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character("fem")


func _select_character(gender: String) -> void:
	if phase != Phase.SELECT:
		return
	Game.chosen_gender = gender
	_start_date_phase()


func _start_date_phase() -> void:
	phase = Phase.DATE
	select_phase.visible = false
	date_phase.visible = true
	date_label.type_text(date_text)


func _go_to_next_scene() -> void:
	if next_scene == null:
		push_warning("Intro: 'Next Scene' não configurado no Inspector.")
		return
	get_tree().change_scene_to_packed(next_scene)
