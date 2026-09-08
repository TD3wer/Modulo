extends Resource
class_name RadioMessage

## Segundos desde o início da fase pra essa mensagem disparar.
@export var trigger_time: float = 10.0

@export_group("Falas por tier de afeto familiar")
@export var lines_high: Array[String] = []
@export var lines_medium: Array[String] = []
@export var lines_low: Array[String] = []


func get_lines(tier: int) -> Array[String]:
	match tier:
		Family.Tier.HIGH:
			return lines_high
		Family.Tier.LOW:
			return lines_low
	return lines_medium
