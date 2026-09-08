extends CanvasLayer

enum Mode { IDLE, BROADCASTING, TOWER_MENU }

## Mensagens agendadas dessa fase — arraste os .tres de RadioMessage aqui.
@export var messages: Array[RadioMessage] = []
## Cenas de torre disponíveis pro menu (uma por ícone). Placeholder até
## você ter os ícones de verdade.
@export var tower_scenes: Array[PackedScene] = []
## Arraste o node do PlacementManager da fase aqui.
@export var placement_manager: Node

@onready var dialogue_box: Control = $DialogueBox
@onready var radio_button: Control = $RadioButton
@onready var radio_anim: AnimatedSprite2D = $RadioButton/AnimatedSprite2D
@onready var tower_menu: Control = $TowerMenu
@onready var tower_menu_items: HBoxContainer = $TowerMenu/Items

var mode: Mode = Mode.IDLE
var _fired_messages: Dictionary = {}  # RadioMessage -> true, evita repetir a mesma mensagem


func _ready() -> void:
	tower_menu.visible = false
	radio_button.gui_input.connect(_on_radio_gui_input)
	dialogue_box.dialogue_finished.connect(_on_broadcast_finished)
	_build_tower_menu()


func _process(_delta: float) -> void:
	if mode == Mode.BROADCASTING:
		return  # não checa mensagem nova enquanto já tá tocando uma

	var elapsed: float = Game.STAGE_DURATION - Game.time_remaining
	for message in messages:
		if _fired_messages.has(message):
			continue
		if elapsed >= message.trigger_time:
			_start_broadcast(message)
			break  # só dispara uma por frame, mesmo se duas venceram juntas


func _start_broadcast(message: RadioMessage) -> void:
	_fired_messages[message] = true

	if mode == Mode.TOWER_MENU:
		_close_tower_menu()  # a lore tem prioridade sobre o menu aberto

	mode = Mode.BROADCASTING
	radio_anim.play("broadcasting")

	dialogue_box.dialogue_lines = message.get_lines(Family.get_tier())
	dialogue_box.current_line = 0  # obrigatório: a caixa não reseta isso sozinha
	dialogue_box.show()
	dialogue_box.start_dialogue()


func _on_broadcast_finished() -> void:
	radio_anim.play("idle")
	dialogue_box.hide()
	mode = Mode.IDLE


func _on_radio_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_radio_pressed()


func _on_radio_pressed() -> void:
	if mode == Mode.BROADCASTING:
		return  # não abre o menu no meio de uma transmissão

	if mode == Mode.TOWER_MENU:
		_close_tower_menu()
	else:
		_open_tower_menu()


func _open_tower_menu() -> void:
	mode = Mode.TOWER_MENU
	tower_menu.visible = true


func _close_tower_menu() -> void:
	mode = Mode.IDLE
	tower_menu.visible = false


func _build_tower_menu() -> void:
	for scene in tower_scenes:
		var icon := TextureButton.new()
		icon.texture_normal = _placeholder_icon()  # troca por asset real quando tiver
		icon.custom_minimum_size = Vector2(32, 32)
		icon.pressed.connect(_on_tower_icon_pressed.bind(scene))
		tower_menu_items.add_child(icon)


func _on_tower_icon_pressed(scene: PackedScene) -> void:
	if placement_manager and placement_manager.has_method("set_active_tower"):
		placement_manager.set_active_tower(scene)
	_close_tower_menu()


func _placeholder_icon() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.6, 1.0))
	return ImageTexture.create_from_image(img)
