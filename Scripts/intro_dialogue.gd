extends Node

## Arraste uma instância de DialogueBox.tscn aqui (pode ser uma nova,
## separada da que o Radio usa — não tem problema ter duas na cena).
@export var dialogue_box: Control
## Arraste o node do WaveSpawner da fase aqui.
@export var wave_spawner: Node
## Arraste o node do PlacementManager da fase aqui.
@export var placement_manager: Node

## Cada linha vira uma página (Enter avança). BBCode funciona normal.
@export_multiline var intro_lines: String = """Recruta: [wave]Comandante! Que bom te ver de volta depois de todo aquele rolo.[/wave]
Recruta: [wave]Ainda bem que tudo foi resolvido e entenderam que você é [b]puro[/b].[/wave]
Recruta: O pessoal da inteligência dá umas bolas fora desse jeito mesmo.
Recruta: Por falar em bola fora... deixaram vazar a rota dos [b]traficantes de chronos[/b] desse bairro.
Recruta: Chegada estimada: [b]8 minutos[/b].
Recruta: Vamos nos preparar. Me diz onde ficar que eu intercepto eles."""

## Falas depois que o jogador coloca a PRIMEIRA torre, logo antes do
## spawner começar de verdade.
@export_multiline var pre_wave_lines: String = "Recruta: E lá vem eles!"


func _ready() -> void:
	_show_dialogue(intro_lines, _on_intro_finished)


func _on_intro_finished() -> void:
	if placement_manager == null:
		push_warning("IntroDialogue: PlacementManager não configurado, pulando direto pro wave.")
		wave_spawner.start()
		return

	# Espera o jogador colocar a primeira torre antes de continuar.
	placement_manager.tower_placed.connect(_on_first_tower_placed, CONNECT_ONE_SHOT)


func _on_first_tower_placed() -> void:
	_show_dialogue(pre_wave_lines, _on_pre_wave_finished)


func _on_pre_wave_finished() -> void:
	wave_spawner.start()


## Helper: transforma um texto multi-linha em páginas e toca na DialogueBox,
## chamando on_finished quando o jogador terminar de ler.
func _show_dialogue(text: String, on_finished: Callable) -> void:
	var lines: Array[String] = []
	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line != "":
			lines.append(line)

	if lines.is_empty() or dialogue_box == null:
		on_finished.call()
		return

	dialogue_box.dialogue_lines = lines
	dialogue_box.current_line = 0
	dialogue_box.show()
	dialogue_box.start_dialogue()

	dialogue_box.dialogue_finished.connect(
		func() -> void:
			dialogue_box.hide()
			on_finished.call(),
		CONNECT_ONE_SHOT
	)
