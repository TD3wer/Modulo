extends Node2D

@export var recruta_scene: PackedScene  # torre inicial/padrão, antes do jogador escolher outra no rádio
@export var cursor_normal: Texture2D
@export var cursor_grab: Texture2D
@export var cursor_scale: int = 4  # multiplicador de tamanho (nearest-neighbor, sem borrar)

@onready var buildable_layer: TileMapLayer = $"../BuildableLayer"

var is_dragging: bool = false
var preview: Node2D = null
var occupied_cells: Dictionary = {}  # Vector2i -> true, evita duas torres na mesma célula
var active_tower_scene: PackedScene
var _cursor_normal_scaled: Texture2D
var _cursor_grab_scaled: Texture2D


func _ready() -> void:
	active_tower_scene = recruta_scene
	_cursor_normal_scaled = _scaled_cursor(cursor_normal)
	_cursor_grab_scaled = _scaled_cursor(cursor_grab)
	Input.set_custom_mouse_cursor(_cursor_normal_scaled)


## Chamado pelo Rádio quando o jogador escolhe um ícone de torre no menu.
func set_active_tower(scene: PackedScene) -> void:
	active_tower_scene = scene


func _scaled_cursor(tex: Texture2D) -> Texture2D:
	if tex == null or cursor_scale <= 1:
		return tex
	var img: Image = tex.get_image()
	img.resize(img.get_width() * cursor_scale, img.get_height() * cursor_scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		else:
			_end_drag()


func _process(_delta: float) -> void:
	if not is_dragging or preview == null:
		return

	var cell := _get_cell_under_mouse()
	preview.global_position = _cell_to_global(cell)
	# verde se pode soltar aqui, vermelho se não pode
	preview.modulate = Color(0.4, 1.0, 0.4, 0.7) if _is_valid_cell(cell) else Color(1.0, 0.4, 0.4, 0.7)


func _start_drag() -> void:
	if active_tower_scene == null or is_dragging:
		return

	is_dragging = true
	Input.set_custom_mouse_cursor(_cursor_grab_scaled)

	preview = active_tower_scene.instantiate()
	preview.is_preview = true  # fantasma: só mostra parado, sem atirar nem detectar nada
	add_child(preview)


func _end_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false
	Input.set_custom_mouse_cursor(_cursor_normal_scaled)

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
	var recruta := active_tower_scene.instantiate()
	get_parent().add_child(recruta)  # entra na árvore ANTES de setar global_position
	recruta.global_position = _cell_to_global(cell)
	occupied_cells[cell] = true
