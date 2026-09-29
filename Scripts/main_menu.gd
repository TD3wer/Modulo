extends Control

## Pra onde o botão Play leva. Hoje aponta pra Cutscene 1 — quando você
## construir a tela de introdução/seleção de personagem, é só trocar
## essa referência pra ela; o resto do menu não precisa mudar nada.
@export var next_scene: PackedScene

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()  # já vem selecionado — dá pra jogar só com teclado/controle


func _on_play_pressed() -> void:
	Game.reset()  # sempre começa do zero: vida cheia, timer zerado

	if next_scene == null:
		push_warning("MainMenu: 'Next Scene' não configurado no Inspector.")
		return

	get_tree().change_scene_to_packed(next_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
