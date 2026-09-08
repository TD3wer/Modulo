extends Node

## Lista de cenas de inimigo. O índice 1 usado no wave_script corresponde
## ao PRIMEIRO elemento dessa lista (é 1-based na string, 0-based aqui dentro).
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_path: NodePath  # arraste o Path2D aqui no Inspector

## Sintaxe:
##   "<indice>x<quantidade>s<intervalo>"  -> spawna um inimigo
##   "w<segundos>"                        -> espera
## Comandos separados por espaço ou quebra de linha.
## Exemplo: "1x3s2 w8 2x1"
##   -> inimigo 1, 3 vezes, 2s de intervalo entre cada
##   -> espera 8 segundos
##   -> inimigo 2, 1 vez
@export_multiline var wave_script: String = "1x3s2 w8 2x1"

signal wave_finished

@onready var path: Path2D = get_node(enemy_path)


func _ready() -> void:
	Game.start_stage_timer()
	_run_wave_script(wave_script)


func _run_wave_script(script: String) -> void:
	var commands: PackedStringArray = script.strip_edges().replace("\n", " ").split(" ", false)

	for command in commands:
		await _run_command(command)

	wave_finished.emit()


func _run_command(command: String) -> void:
	if command.begins_with("w"):
		var seconds: float = command.substr(1).to_float()
		await get_tree().create_timer(seconds).timeout
		return

	var parts: PackedStringArray = command.split("x")
	if parts.size() != 2:
		push_warning("WaveSpawner: comando inválido '%s'" % command)
		return

	var enemy_index: int = int(parts[0]) - 1  # 1-based na string, 0-based no array
	var rest: PackedStringArray = parts[1].split("s")
	var count: int = int(rest[0])
	var interval: float = float(rest[1]) if rest.size() > 1 else 1.0

	for i in range(count):
		_spawn_enemy(enemy_index)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout


func _spawn_enemy(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemy_scenes.size():
		push_warning("WaveSpawner: índice de inimigo inválido: %d" % (enemy_index + 1))
		return

	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_follow.progress = 0.0
	path.add_child(path_follow)

	var enemy := enemy_scenes[enemy_index].instantiate()
	path_follow.add_child(enemy)
