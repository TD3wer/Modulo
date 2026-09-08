extends Node

signal affection_changed(new_affection: float)

enum Tier { LOW, MEDIUM, HIGH }

const MAX_AFFECTION: float = 100.0
const AFFECTION_LOSS_PER_LIFE: float = 15.0  # quanto cai por coração perdido
const TIER_HIGH_THRESHOLD: float = 66.0
const TIER_MEDIUM_THRESHOLD: float = 33.0

var affection: float = MAX_AFFECTION


func _ready() -> void:
	# Family DEPENDE do Game (escuta o signal dele), mas o Game nunca
	# precisa saber que Family existe. Isso é o que deixa dar reset,
	# remover, ou até substituir esse autoload sem tocar no Game.
	Game.life_changed.connect(_on_life_changed)


func _on_life_changed(_new_life: int) -> void:
	adjust_affection(-AFFECTION_LOSS_PER_LIFE)


## Público de propósito: outras mecânicas futuras (uma missão salva, um
## refém perdido, etc.) podem chamar isso direto, sem precisar passar
## pelo Game nem pela vida do jogador.
func adjust_affection(amount: float) -> void:
	affection = clamp(affection + amount, 0.0, MAX_AFFECTION)
	affection_changed.emit(affection)


func get_tier() -> Tier:
	if affection >= TIER_HIGH_THRESHOLD:
		return Tier.HIGH
	elif affection >= TIER_MEDIUM_THRESHOLD:
		return Tier.MEDIUM
	return Tier.LOW


func reset() -> void:
	affection = MAX_AFFECTION
