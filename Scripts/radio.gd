extends CanvasLayer

enum Mode { IDLE, BROADCASTING, TOWER_MENU }

## Toca quando o jogador clica no rádio PELA PRIMEIRA VEZ (antes disso o
## rádio só fica com a animação "broadcasting" chamando atenção).
@export_multiline var intro_lines: String = """Recruta: [wave]Comandante! Que bom te ver de volta depois de todo aquele rolo.[/wave]
Recruta: [wave]Ainda bem que tudo foi resolvido e entenderam que você é [b]puro[/b].[/wave]
Recruta: O pessoal da inteligência dá umas bolas fora desse jeito mesmo.
Recruta: Por falar em bola fora... deixaram vazar a rota dos [b]traficantes de chronos[/b] desse bairro.
Recruta: Chegada estimada: [b]8 minutos[/b].
Recruta: Vamos nos preparar. Me diz onde ficar que eu intercepto eles."""

## Toca assim que a PRIMEIRA torre é colocada, logo antes do spawner
## liberar os inimigos de verdade.
@export_multiline var pre_wave_lines: String = "Recruta: E lá vem eles!"

## Mensagens agendadas que tocam DEPOIS que a fase já começou.
## Formato: @segundos / HIGH / MEDIUM / LOW — sem precisar de .tres.
@export_multiline var messages_script: String = """@45
HIGH
Recruta: [wave]Tá tudo calmo por aqui, comandante.[/wave]
MEDIUM
Recruta: Vamos manter o foco na missão.
LOW
Recruta: ...silêncio no rádio."""

@export var tower_scenes: Array[PackedScene] = []
@export var tower_portraits: Array[Texture2D] = []  # mesmo índice de tower_scenes
@export var placement_manager: Node
@export var wave_spawner: Node

@export_group("Som")
@export var broadcasting_sound: AudioStream
@export var broadcasting_pitch_min: float = 0.95
@export var broadcasting_pitch_max: float = 1.05

@onready var dialogue_box: Control = $DialogueBox
@onready var radio_button: Control = $RadioButton
@onready var radio_anim: AnimatedSprite2D = $RadioButton/AnimatedSprite2D
@onready var tower_menu: Control = $TowerMenu
@onready var tower_menu_items: HBoxContainer = $TowerMenu/Items
@onready var broadcast_audio: AudioStreamPlayer = $BroadcastAudio

var mode: Mode = Mode.IDLE
var scheduled_messages: Array[RadioMessageData] = []
var _fired_messages: Dictionary = {}
var _intro_done: bool = false
var _pending_scheduled_message: RadioMessageData = null  # esperando o jogador clicar pra abrir
var _tower_icons: Dictionary = {}  # PackedScene -> Button
var _tower_overlays: Dictionary = {}  # PackedScene -> ColorRect (camada cinza do cooldown)
var _used_towers: Dictionary = {}  # PackedScene -> true, depois de colocada


class RadioMessageData:
	var trigger_time: float = 0.0
	var lines_high: Array[String] = []
	var lines_medium: Array[String] = []
	var lines_low: Array[String] = []

	func get_lines(tier: int) -> Array[String]:
		match tier:
			Family.Tier.HIGH:
				return lines_high
			Family.Tier.LOW:
				return lines_low
		return lines_medium


func _ready() -> void:
	# Deixa o Rádio (e tudo dentro dele: DialogueBox, botões) processando
	# mesmo com get_tree().paused = true — senão nem o Enter pra avançar
	# a fala funcionaria durante a pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS

	radio_button.gui_input.connect(_on_radio_gui_input)

	scheduled_messages = _parse_messages(messages_script)
	_build_tower_menu()
	tower_menu.visible = false

	if placement_manager:
		placement_manager.tower_placed.connect(_on_any_tower_placed)
		placement_manager.tower_removed.connect(_on_tower_removed)

	_start_ringing()  # animação + som avisando que tem mensagem esperando

	# radio_button.global_position só fica confiável DEPOIS do primeiro
	# layout pass — se calcularmos aqui dentro do _ready(), pega um valor
	# desatualizado (geralmente (0,0)) e o menu nasce fora da tela.
	call_deferred("_setup_tower_menu_layout")


## Calcula o tamanho do menu a partir da quantidade real de ícones (não
## chuta um valor fixo) e posiciona ele relativo à posição GLOBAL do botão
## do rádio — assim não depende de saber o tamanho do canvas base.
func _setup_tower_menu_layout() -> void:
	const ICON_SIZE: float = 32.0
	const PADDING: float = 4.0

	var count: int = maxi(tower_scenes.size(), 1)
	var menu_size := Vector2(
		count * ICON_SIZE + (count + 1) * PADDING,
		ICON_SIZE + PADDING * 2
	)

	tower_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tower_menu.size = menu_size
	tower_menu.modulate = Color.WHITE
	tower_menu.self_modulate = Color.WHITE
	tower_menu.z_index = 100  # garante que fica por cima de qualquer outro Control do Radio

	# Fica do lado ESQUERDO do rádio, alinhado na horizontal com ele.
	var target_x: float = radio_button.global_position.x - menu_size.x - PADDING
	var target_y: float = radio_button.global_position.y + (radio_button.size.y - menu_size.y) / 2.0

	# Trava dentro da área visível, pro menu nunca nascer fora do canvas
	# nem que o rádio esteja bem coladinho numa borda.
	var canvas_size: Vector2 = get_viewport().get_visible_rect().size
	target_x = clampf(target_x, 0.0, maxf(canvas_size.x - menu_size.x, 0.0))
	target_y = clampf(target_y, 0.0, maxf(canvas_size.y - menu_size.y, 0.0))

	tower_menu.global_position = Vector2(target_x, target_y)
	print("Radio: radio_button.global_position = ", radio_button.global_position, " size = ", radio_button.size, " canvas = ", canvas_size, " | tower_menu.global_position = ", tower_menu.global_position)

	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.95, 0.95, 0.95)  # claro de propósito: fundo do jogo é preto, precisa de contraste
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower_menu.add_child(bg)
	tower_menu.move_child(bg, 0)  # atrás dos ícones


func _process(_delta: float) -> void:
	if mode == Mode.BROADCASTING or not _intro_done or _pending_scheduled_message != null:
		return  # não checa mensagem nova durante uma fala, antes da intro, ou com uma já esperando clique

	var elapsed: float = Game.STAGE_DURATION - Game.time_remaining
	for i in range(scheduled_messages.size()):
		if _fired_messages.has(i):
			continue
		if elapsed >= scheduled_messages[i].trigger_time:
			_fired_messages[i] = true
			if mode == Mode.TOWER_MENU:
				_close_tower_menu()
			_pending_scheduled_message = scheduled_messages[i]
			_start_ringing()
			break


func _on_radio_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_radio_pressed()


func _on_radio_pressed() -> void:
	if mode == Mode.BROADCASTING:
		return

	if not _intro_done:
		_stop_ringing()
		_start_broadcast(_parse_lines(intro_lines), _on_intro_finished)
		return

	if _pending_scheduled_message != null:
		var message := _pending_scheduled_message
		_pending_scheduled_message = null
		_stop_ringing()
		_start_broadcast(message.get_lines(Family.get_tier()), _on_broadcast_finished)
		return

	if mode == Mode.TOWER_MENU:
		_close_tower_menu()
	else:
		_open_tower_menu()


func _on_intro_finished() -> void:
	_intro_done = true

	if placement_manager:
		placement_manager.tower_placed.connect(_on_first_tower_placed, CONNECT_ONE_SHOT)
		print("Radio: conectou _on_first_tower_placed? ", placement_manager.tower_placed.is_connected(_on_first_tower_placed))
	else:
		print("Radio: placement_manager é null, não deu pra conectar _on_first_tower_placed")


func _on_first_tower_placed(_scene: PackedScene) -> void:
	print("Radio: _on_first_tower_placed disparou")
	_start_broadcast(_parse_lines(pre_wave_lines), _on_pre_wave_finished)


func _on_pre_wave_finished() -> void:
	print("Radio: pre_wave terminou, chamando wave_spawner.start() em ", wave_spawner)
	if wave_spawner:
		wave_spawner.start()


func _on_broadcast_finished() -> void:
	pass  # gancho genérico pra mensagens agendadas, não precisa fazer nada extra por enquanto


func _open_tower_menu() -> void:
	mode = Mode.TOWER_MENU
	tower_menu.visible = true


func _close_tower_menu() -> void:
	mode = Mode.IDLE
	tower_menu.visible = false


## Toca uma sequência de falas na DialogueBox, cuidando da animação do
## rádio e chamando on_finished quando o jogador terminar de ler.
func _start_broadcast(lines: Array[String], on_finished: Callable) -> void:
	if lines.is_empty():
		on_finished.call()
		return

	if mode == Mode.TOWER_MENU:
		_close_tower_menu()

	mode = Mode.BROADCASTING
	radio_anim.play("broadcasting")
	get_tree().paused = true  # congela inimigos, balas e o timer da wave

	dialogue_box.dialogue_lines = lines
	dialogue_box.current_line = 0
	dialogue_box.show()
	dialogue_box.start_dialogue()

	dialogue_box.dialogue_finished.connect(
		func() -> void:
			dialogue_box.hide()
			radio_anim.play("idle")
			mode = Mode.IDLE
			get_tree().paused = false
			on_finished.call(),
		CONNECT_ONE_SHOT
	)


## Animação + som avisando "tem mensagem esperando, clica em mim". O som
## toca com UM pitch aleatório sorteado no início, e mantém esse mesmo
## tom em todas as repetições (o loop em si é nativo do áudio — lembra
## de deixar 'Loop' LIGADO nas configurações de importação desse som).
func _start_ringing() -> void:
	radio_anim.play("broadcasting")
	if broadcasting_sound == null:
		return
	broadcast_audio.stream = broadcasting_sound
	broadcast_audio.pitch_scale = randf_range(broadcasting_pitch_min, broadcasting_pitch_max)
	broadcast_audio.play()


func _stop_ringing() -> void:
	broadcast_audio.stop()


func _parse_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line != "":
			lines.append(line)
	return lines


func _parse_messages(text: String) -> Array[RadioMessageData]:
	var result: Array[RadioMessageData] = []
	var current: RadioMessageData = null
	var current_tier: String = ""

	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line == "":
			continue

		if line.begins_with("@"):
			if current:
				result.append(current)
			current = RadioMessageData.new()
			current.trigger_time = line.substr(1).to_float()
			current_tier = ""
			continue

		var upper: String = line.to_upper()
		if upper == "HIGH" or upper == "MEDIUM" or upper == "LOW":
			current_tier = upper
			continue

		if current == null:
			push_warning("Radio: fala fora de qualquer bloco '@tempo': '%s'" % line)
			continue

		match current_tier:
			"HIGH":
				current.lines_high.append(line)
			"MEDIUM":
				current.lines_medium.append(line)
			"LOW":
				current.lines_low.append(line)
			_:
				# nenhum HIGH/MEDIUM/LOW visto ainda nessa mensagem — essa
				# fala vale igual pra qualquer tier de afeto
				current.lines_high.append(line)
				current.lines_medium.append(line)
				current.lines_low.append(line)

	if current:
		result.append(current)

	return result


func _build_tower_menu() -> void:
	const ICON_SIZE: float = 32.0
	const PADDING: float = 4.0

	print("Radio: construindo menu com %d torre(s) em Tower Scenes" % tower_scenes.size())
	for i in range(tower_scenes.size()):
		var scene: PackedScene = tower_scenes[i]

		var icon := Button.new()
		icon.text = ""
		icon.flat = true  # sem fundo padrão de botão — só o retrato e o overlay aparecem
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)  # forçado direto, não depende do container recalcular
		icon.position = Vector2(PADDING + i * (ICON_SIZE + PADDING), PADDING)
		icon.button_down.connect(_on_tower_icon_pressed.bind(scene))
		tower_menu.add_child(icon)  # direto no TowerMenu, sem passar pelo Items/HBoxContainer

		if i < tower_portraits.size() and tower_portraits[i] != null:
			var portrait := TextureRect.new()
			portrait.texture = tower_portraits[i]
			portrait.stretch_mode = TextureRect.STRETCH_SCALE
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.add_child(portrait)

		# Camada cinza do cooldown: anchor_top vai de 0 (cobre tudo) até 1
		# (encolhe até sumir, "descendo" pro fundo do retrato).
		var overlay := ColorRect.new()
		overlay.color = Color(0.1, 0.1, 0.1, 0.75)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.anchor_left = 0.0
		overlay.anchor_right = 1.0
		overlay.anchor_top = 0.0
		overlay.anchor_bottom = 1.0
		overlay.visible = false
		icon.add_child(overlay)

		_tower_icons[scene] = icon
		_tower_overlays[scene] = overlay


func _on_any_tower_placed(scene: PackedScene) -> void:
	_used_towers[scene] = true
	_cover_icon(scene)


func _on_tower_removed(scene: PackedScene, cooldown: float) -> void:
	_used_towers.erase(scene)
	_start_icon_cooldown(scene, cooldown)


## Cobre o ícone inteiro, sem animação — usado assim que a torre é
## colocada (fica bloqueado até ser removida, aí sim entra em cooldown).
func _cover_icon(scene: PackedScene) -> void:
	if not _tower_icons.has(scene):
		return
	var icon: BaseButton = _tower_icons[scene]
	var overlay: ColorRect = _tower_overlays.get(scene)

	icon.disabled = true
	if overlay:
		overlay.anchor_top = 0.0
		overlay.visible = true


func _start_icon_cooldown(scene: PackedScene, cooldown: float) -> void:
	if not _tower_icons.has(scene):
		return
	var icon: BaseButton = _tower_icons[scene]
	var overlay: ColorRect = _tower_overlays.get(scene)

	icon.disabled = true

	if overlay:
		overlay.visible = true
		overlay.anchor_top = 0.0
		var tween := create_tween()
		tween.tween_property(overlay, "anchor_top", 1.0, cooldown)
		await tween.finished
		overlay.visible = false

	icon.disabled = false


func _on_tower_icon_pressed(scene: PackedScene) -> void:
	if placement_manager and placement_manager.has_method("set_active_tower"):
		placement_manager.set_active_tower(scene)
	_close_tower_menu()
