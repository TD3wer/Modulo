extends Control
## Lista de falas. Edita direto aqui no Inspector, sem precisar mexer no
## código pra cada fala nova. Aceita BBCode, tipo [b]negrito[/b] ou
## [wave]texto[/wave] (efeito customizado — veja wave_text_effect.gd e as
## instruções de como plugar ele no RichTextLabel).
@export var dialogue_lines: Array[String] = [
	"Primeira linha de texto aqui...",
	"Segunda linha, aparece quando avança.",
	"Última linha antes de fechar a caixa.",
]
## AJUSTA esse caminho pro node de texto real dentro da tua cena
## (o "quadro" onde você escreve as falas).
@onready var text_node: RichTextLabel = $NinePatchRect/RichTextLabel
## Segundos entre cada letra aparecendo no efeito de "escrevendo". Menor
## número = mais rápido.
@export var seconds_per_character: float = 0.03
var current_line: int = 0
var _typewriter_tween: Tween
## Emitido toda vez que uma linha nova aparece na tela, com o índice dela
## e o texto. Quem precisar reagir a uma linha específica (tocar uma
## animação, mostrar um alerta, etc.) escuta esse signal de FORA — essa
## caixa de texto não precisa saber nada sobre personagens, tilemaps ou
## outras cenas. É isso que deixa reusar essa mesma DialogueBox em
## qualquer outra cutscene sem reconfigurar nada dela.
signal line_shown(index: int, line_text: String)
## Emitido quando termina a última fala (depois do último advance()).
signal dialogue_finished
func _ready() -> void:
	text_node.bbcode_enabled = true
## Chama isso de fora (depois de conectar os signals) pra começar o diálogo.
## Não chamamos show_line() direto no _ready() porque _ready() dos filhos
## roda ANTES do _ready() do pai — se a primeira linha aparecesse sozinha
## aqui, o line_shown ia disparar antes de quem tá do lado de fora (tipo
## o cutscene_controller) ter conectado o signal ainda.
func start_dialogue() -> void:
	show_line(current_line)
func _unhandled_input(event: InputEvent) -> void:
	# Sem isso, apertar "ui_accept" com a caixa ESCONDIDA (hide() já chamado)
	# ainda incrementa current_line por baixo dos panos — inofensivo quando
	# só existe UMA cutscene, mas quebra qualquer sistema que reusa a mesma
	# instância várias vezes (como o Radio vai fazer).
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		advance()
func advance() -> void:
	# Se o texto ainda tá aparecendo aos poucos, o primeiro Enter só
	# completa a linha na hora — praticamente todo jogo com dialogue box
	# faz isso, fica estranho sem essa opção.
	if _typewriter_tween != null and _typewriter_tween.is_running():
		_complete_typewriter()
		return
	current_line += 1
	if current_line >= dialogue_lines.size():
		dialogue_finished.emit()
		hide()
		return
	show_line(current_line)
func show_line(index: int) -> void:
	var line_text: String = dialogue_lines[index]
	_start_typewriter(line_text)
	line_shown.emit(index, line_text)
func _start_typewriter(line_text: String) -> void:
	if _typewriter_tween != null:
		_typewriter_tween.kill()
	text_node.text = line_text
	text_node.visible_ratio = 0.0
	var duration: float = line_text.length() * seconds_per_character
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(text_node, "visible_ratio", 1.0, duration)
func _complete_typewriter() -> void:
	if _typewriter_tween != null:
		_typewriter_tween.kill()
	text_node.visible_ratio = 1.0
