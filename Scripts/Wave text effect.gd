extends RichTextEffect
class_name WaveTextEffect

## Tag do BBCode que essa classe registra. Usa assim numa fala:
## [b][wave]PALAVRA[/wave][/b]  -> negrito + balançando
## [wave amp=10 freq=0.8 speed=5]texto[/wave]  -> parâmetros customizados
## [wave amp=6 freq=3.14 speed=4]texto[/wave]  -> letras alternando (uma sobe, a vizinha desce)
var bbcode := "waver
"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amplitude: float = char_fx.env.get("amp", 6.0)   # o quanto sobe/desce, em pixels
	var frequency: float = char_fx.env.get("freq", 0.5)  # desfasamento entre letras vizinhas
	var speed: float = char_fx.env.get("speed", 4.0)     # velocidade do balanço

	var time: float = Time.get_ticks_msec() / 1000.0
	var offset_y: float = sin(time * speed + char_fx.relative_index * frequency) * amplitude

	char_fx.offset += Vector2(0, offset_y)
	return true
