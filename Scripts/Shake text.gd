extends RichTextEffect
class_name ShakeTextEffect

## Tag do BBCode: [shake]texto[/shake]
## [shake amp=3 speed=30]texto[/shake] pra ajustar intensidade/velocidade
##
## Diferente do [wave], aqui NÃO tem interpolação entre os valores — o
## salto é instantâneo a cada "step". É exatamente essa falta de suavização
## que dá a sensação de tremor/vibração em vez de balanço.
var bbcode := "shaker"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amplitude: float = char_fx.env.get("amp", 2.0)    # intensidade do tremor, em pixels (mantém baixo, tipo 1-4)
	var speed: float = char_fx.env.get("speed", 20.0)     # quantas vezes por segundo re-randomiza (maior = mais nervoso)

	var time: float = Time.get_ticks_msec() / 1000.0
	var step: int = int(time * speed)

	var seed_value: int = char_fx.relative_index

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_value, step, 0))
	var offset_x: float = rng.randf_range(-amplitude, amplitude)

	rng.seed = hash(Vector3i(seed_value, step, 1))
	var offset_y: float = rng.randf_range(-amplitude, amplitude)

	char_fx.offset += Vector2(offset_x, offset_y)
	return true
