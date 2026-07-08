extends Node
## "Characters" autoload: a registry of every CharacterProfile, loaded from
## res://characters/. Look one up by id with get_profile("bob") from anywhere — a
## scene flow, the NpcDirector (to spawn a named NPC), etc. This is also where a
## recurring character's cross-scene state would live later.

var _by_id: Dictionary = {}

func _ready() -> void:
	_load_dir("res://characters/")

func _load_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var fname := f
		if fname.ends_with(".remap"):        # exported builds rename .tres -> .tres.remap
			fname = fname.trim_suffix(".remap")
		if not (fname.ends_with(".tres") or fname.ends_with(".res")):
			continue
		var res = load(path + fname)
		if res is CharacterProfile and String(res.id) != "":
			_by_id[res.id] = res

## The profile for `id` (String or StringName), or null if unknown.
func get_profile(id) -> CharacterProfile:
	return _by_id.get(StringName(id), null)

## Every loaded profile (for debugging / menus).
func all() -> Array:
	return _by_id.values()
