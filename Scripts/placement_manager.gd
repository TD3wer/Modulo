extends Node2D

signal tower_placed(scene: PackedScene, slot_index: int)
signal tower_removed(scene: PackedScene, slot_index: int, cooldown: float)

@export var recruta_scene: PackedScene  # torre inicial/padrão, antes do jogador escolher outra no rádio

@onready var buildable_layer: TileMapLayer = $"../BuildableLayer"

var is_placing: bool = false
var preview: Node2D = null
var occupied_cells: Dictionary = {}  # Vector2i -> true, evita duas torres na mesma célula
var active_tower_scene: PackedScene
var active_slot_index: int = -1
var active_tower_cost: int = 0


func _ready() -> void:
	active_tower_scene = recruta_scene


## Chamado pelo Rádio no exato momento em que o jogador PRESSIONA o ícone
## (button_down, não "pressed" — que só dispara ao soltar). O arraste
## começa junto com o clique, sem soltar o botão do mouse.
func set_active_tower(scene: PackedScene, slot_index: int) -> void:
	active_tower_scene = scene
	active_slot_index = slot_index
	_start_placing()


func _start_placing() -> void:
	if active_tower_scene == null:
		return

	var temp := active_tower_scene.instantiate()
	active_tower_cost = temp.morale_cost if "morale_cost" in temp else 0

	if not Game.can_afford(active_tower_cost):
		temp.queue_free()
		push_warning("PlacementManager: moral insuficiente pra essa torre (custa %d)." % active_tower_cost)
		return

	if is_placing and preview:
		preview.queue_free()  # trocou de torre no meio do processo, descarta o fantasma antigo

	is_placing = true
	preview = temp
	preview.is_preview = true
	add_child(preview)


func _process(_delta: float) -> void:
	if not is_placing or preview == null:
		return

	var cell := _get_cell_under_mouse()
	preview.global_position = _cell_to_global(cell)
	# verde se pode soltar aqui, vermelho se não pode
	preview.modulate = Color(0.4, 1.0, 0.4, 0.7) if _is_valid_cell(cell) else Color(1.0, 0.4, 0.4, 0.7)

	# Solta o botão em QUALQUER lugar confirma — checando o estado do
	# mouse a cada frame em vez de esperar um evento de input específico,
	# não importa se o clique "nasceu" no ícone (um Control) ou no mapa.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_confirm_placement()


func _confirm_placement() -> void:
	is_placing = false

	var cell := _get_cell_under_mouse()
	if _is_valid_cell(cell):
		_place_recruta(cell)

	preview.queue_free()
	preview = null


func _get_cell_under_mouse() -> Vector2i:
	var mouse_local: Vector2 = buildable_layer.to_local(get_global_mouse_position())
	return buildable_layer.local_to_map(mouse_local)


func _cell_to_global(cell: Vector2i) -> Vector2:
	return buildable_layer.to_global(buildable_layer.map_to_local(cell))


func _is_valid_cell(cell: Vector2i) -> bool:
	var is_marked: bool = buildable_layer.get_cell_source_id(cell) != -1
	var is_free: bool = not occupied_cells.has(cell)
	return is_marked and is_free


func _place_recruta(cell: Vector2i) -> void:
	if not Game.spend_for_tower(active_tower_cost):
		return  # segurança: não deveria chegar aqui sem conseguir pagar

	var recruta := active_tower_scene.instantiate()
	get_parent().add_child(recruta)  # entra na árvore ANTES de setar global_position
	recruta.global_position = _cell_to_global(cell)
	occupied_cells[cell] = true

	recruta.placed_cell = cell
	recruta.tower_scene_ref = active_tower_scene
	recruta.slot_index = active_slot_index
	recruta.removed.connect(_on_recruta_removed)

	tower_placed.emit(active_tower_scene, active_slot_index)


func _on_recruta_removed(cell: Vector2i, scene: PackedScene, slot_index: int, cooldown: float) -> void:
	occupied_cells.erase(cell)  # libera a célula pra poder construir ali de novo
	tower_removed.emit(scene, slot_index, cooldown)
