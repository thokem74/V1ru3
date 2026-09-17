## Pure campaign progression: four waves per landscape and three landscapes per victory.
class_name WaveController
extends RefCounted
const LANDSCAPES := 3
var landscape := 1
var wave := 1

## Return the ordered enemy role IDs for the current wave and landscape.
## Difficulty adds roles/counts gradually, with no more than 24 simultaneous enemies.
func roster() -> Array[int]:
	var counts := [wave + 2, 0 if wave == 1 else wave, 0 if wave < 3 else wave, 0]
	if landscape > 1:
		counts[0] += landscape - 1
		counts[3] = landscape
	var result: Array[int] = []
	for kind in range(4):
		for i in range(counts[kind]):
			if result.size() < 24:
				result.append(kind)
	return result

## Advance a cleared wave and return wave, landscape, or victory to guide the UI transition.
## Only the game controller calls this after presenting results; it does not check enemy counts.
func advance() -> String:
	if wave < 4:
		wave += 1
		return "wave"
	if landscape >= LANDSCAPES:
		return "victory"
	wave = 1
	landscape += 1
	return "landscape"
