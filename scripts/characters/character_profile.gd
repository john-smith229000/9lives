extends Resource
class_name CharacterProfile
## One file per character = their reusable identity + personality. Story/plot lines
## live in the scene flow; a character carries only what's theirs everywhere:
## their name, model, voice blip, walk speed, and a library of short "expressions"
## (greetings, reactions, catchphrases) a flow can fire with express().
##
## Leave a field blank to fall back to the shared default (so several characters can
## share one model/voice now and diverge later, one field at a time).

@export var id: StringName = ""
@export var display_name: String = ""
## Optional unique model (a PackedScene). Blank = whatever the scene already uses.
@export var model: PackedScene
## Optional voice blip played while their text types out. Blank = silent.
@export var voice: AudioStream
## Optional walk speed override (0 = use the default).
@export var walk_speed: float = 0.0
## Character-owned lines, keyed by name. Each value is a String or an array of
## Strings (a multi-line expression). e.g. {"greeting": "Well met.", ...}
@export var expressions: Dictionary = {}

## The lines for an expression key as a plain Array (empty if the key is unknown).
func expression(key: String) -> Array:
	if not expressions.has(key):
		return []
	var v = expressions[key]
	if v is Array or v is PackedStringArray:
		var a: Array = []
		for l in v:
			a.append(str(l))
		return a
	return [str(v)]
