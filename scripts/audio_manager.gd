extends Node
## AudioManager — the game's single hub for sound. Registered as the "AudioManager"
## autoload (see project.godot).
##
## Why this exists: so that (1) every sound is DEFINED IN ONE PLACE (the _LIBRARY
## below) instead of scattered ext_resources across scenes, (2) all playback routes
## through named mixer buses an options menu can turn down later, and (3) callers
## fire a sound with a single line and never have to add/track/free their own
## AudioStreamPlayer — a small pool is recycled here.
##
## Adding a new sound = add one entry to _LIBRARY, then:
##     AudioManager.play_3d(&"my_sound", some_node.global_position)   # positional
##     AudioManager.play_2d(&"ui_click")                             # non-positional
##
## TWO KINDS OF PLAYBACK:
##   • One-shots (a splash, a thud, a UI blip) -> play_2d / play_3d. Pooled here.
##   • Continuous sounds tied to a MOVING node (footsteps, an engine hum) -> the node
##     owns its own looping player so it follows automatically; it asks configure()
##     for the stream/bus/volume so the DEFINITION still lives here. See Player's
##     footsteps for the reference example.

## Mixer buses (must match audio/default_bus_layout.tres). Master (index 0) always
## exists; Music and SFX route into it so their volumes can be set independently.
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

## The sound catalogue. name -> definition dictionary. Fields (all but "path" optional):
##   path        res:// path to the stream                         (required)
##   bus         mixer bus to route through                        (default BUS_SFX)
##   volume_db   level trim in decibels, 0 = as recorded           (default 0.0)
##   loop        true for continuous sounds (footsteps, ambience)  (default false)
##   pitch_min   randomised pitch floor, per play                  (default 1.0)
##   pitch_max   randomised pitch ceiling, per play                (default 1.0)
##               (min == max == 1.0 means no variation)
##   unit_size   3D only (play_3d): distance (m) the sound carries before falloff.
##
## NOTE on play_3d / positional audio: prefer play_2d for gameplay cues in this game.
## The iso camera always frames the cat, so there's little to spatialise, and 3D
## audio has two traps here: (1) AudioStreamPlayer3D clamps output to max_db (+3 dB
## default), so a big volume_db does nothing; (2) retro mode renders into a
## SubViewport with no 3D audio listener, so positional sounds go SILENT there.
## play_3d is kept for future use (e.g. after enabling a listener on that viewport).
const _LIBRARY := {
	&"grass_walk": {
		"path": "res://audio/grass_walk.ogg",
		"bus": BUS_SFX,
		"volume_db": 25.0,      # non-positional, so this is honoured directly (0 = full)
		"loop": true,          # looped continuously while the cat walks
		"pitch_min": 0.92,     # each walking bout gets a slightly different pitch so
		"pitch_max": 1.08,     # repeated walks don't sound mechanically identical
	},
	&"water_splash": {
		"path": "res://audio/water_splash.ogg",
		"bus": BUS_SFX,
		"volume_db": 0.0,
		"pitch_min": 0.92,     # slight variation so repeated splashes aren't identical
		"pitch_max": 1.08,
	},
}

## Steady-state size of each one-shot player pool. Both pools grow on demand if a
## burst needs more players at once, so these are just sensible starting counts.
const _POOL_SIZE_2D := 6
const _POOL_SIZE_3D := 12

## Absolute volume (dB) a looping sound fades to/from — low enough to be inaudible
## regardless of the sound's target level, so fades always reach true silence.
const _FADE_SILENCE_DB := -60.0

var _streams: Dictionary = {}                  # name -> AudioStream (loaded once)
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	# Sound should keep working even while the tree is paused (e.g. a pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_library()
	for i in _POOL_SIZE_2D:
		_pool_2d.append(_new_player_2d())
	for i in _POOL_SIZE_3D:
		_pool_3d.append(_new_player_3d())

## Load every stream in the library once, applying looping where requested.
func _load_library() -> void:
	for name in _LIBRARY:
		var def: Dictionary = _LIBRARY[name]
		var path: String = def.get("path", "")
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: could not load '%s' at %s" % [name, path])
			continue
		if def.get("loop", false):
			_enable_loop(stream)
		_streams[name] = stream

## --- Public API -------------------------------------------------------------

## Play a one-shot at a world position (distance-attenuated 3D audio). Returns the
## player used, in case the caller wants to stop/track it. Safe to ignore.
func play_3d(sound: StringName, position: Vector3, pitch_override: float = -1.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("AudioManager: play_3d unknown sound '%s'" % sound)
		return null
	var def: Dictionary = _LIBRARY[sound]
	var p := _free_player_3d()
	p.stream = stream
	p.bus = def.get("bus", BUS_SFX)
	p.volume_db = def.get("volume_db", 0.0)
	p.pitch_scale = pitch_override if pitch_override > 0.0 else _roll_pitch(def)
	p.unit_size = def.get("unit_size", 10.0)
	p.global_position = position
	p.play()
	return p

## Play a one-shot with no positioning (UI blips, non-diegetic cues). Returns the
## player used. Safe to ignore.
func play_2d(sound: StringName, pitch_override: float = -1.0) -> AudioStreamPlayer:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("AudioManager: play_2d unknown sound '%s'" % sound)
		return null
	var def: Dictionary = _LIBRARY[sound]
	var p := _free_player_2d()
	p.stream = stream
	p.bus = def.get("bus", BUS_SFX)
	p.volume_db = def.get("volume_db", 0.0)
	p.pitch_scale = pitch_override if pitch_override > 0.0 else _roll_pitch(def)
	p.play()
	return p

## Configure a player node THE CALLER OWNS (an AudioStreamPlayer / *2D / *3D) from a
## library entry: sets its stream, bus and volume. Use this for continuous sounds
## that must live on a moving node (so they follow it) while keeping the sound's
## definition here. Returns false if the sound is unknown. Does NOT call play().
func configure(player: Node, sound: StringName) -> bool:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("AudioManager: configure unknown sound '%s'" % sound)
		return false
	var def: Dictionary = _LIBRARY[sound]
	player.stream = stream
	player.bus = def.get("bus", BUS_SFX)
	player.volume_db = def.get("volume_db", 0.0)
	if player is AudioStreamPlayer3D and def.has("unit_size"):
		player.unit_size = def["unit_size"]
	return true

## --- Looping sounds with fades (footsteps, ambience) ------------------------
## Start a looping sound on a player the caller OWNS, made to sound natural:
##   • begins at a RANDOM point in the clip (so the loop never audibly restarts
##     from the same spot, and repeated walks don't line up identically),
##   • picks a fresh pitch within the sound's range for this bout, and
##   • FADES the volume up from silence over `fade_time`.
## If the player is already playing (e.g. the cat kept walking), the playback
## position is left untouched and we just fade back to full — a seamless resume,
## no restart. Pair with stop_loop().
func start_loop(player: Node, sound: StringName, fade_time: float = 0.15) -> void:
	if player == null:
		return
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("AudioManager: start_loop unknown sound '%s'" % sound)
		return
	var def: Dictionary = _LIBRARY[sound]
	var target_db: float = def.get("volume_db", 0.0)
	_kill_fade(player)
	if not player.playing:
		player.stream = stream
		player.bus = def.get("bus", BUS_SFX)
		if player is AudioStreamPlayer3D and def.has("unit_size"):
			player.unit_size = def["unit_size"]
		player.pitch_scale = _roll_pitch(def)
		var length := stream.get_length()
		var from_pos := randf() * length if length > 0.0 else 0.0
		# Start at (or just under) silence, then swell up to target.
		player.volume_db = minf(_FADE_SILENCE_DB, target_db - 12.0)
		player.play(from_pos)
	var tw := player.create_tween()
	tw.tween_property(player, "volume_db", target_db, fade_time)
	player.set_meta(&"_fade_tween", tw)

## Fade a looping sound out over `fade_time`, then stop it. Safe to call when it's
## already stopped (no-op). If start_loop() is called again during the fade-out,
## the fade is cancelled and playback resumes from where it was.
func stop_loop(player: Node, fade_time: float = 0.2) -> void:
	if player == null or not player.playing:
		return
	_kill_fade(player)
	var tw := player.create_tween()
	tw.tween_property(player, "volume_db", _FADE_SILENCE_DB, fade_time)
	tw.tween_callback(player.stop)
	player.set_meta(&"_fade_tween", tw)

## Kill any in-progress fade tween on this player so fades never stack/fight.
func _kill_fade(player: Node) -> void:
	if player.has_meta(&"_fade_tween"):
		var tw = player.get_meta(&"_fade_tween")
		if tw is Tween and tw.is_valid():
			tw.kill()

## Set a bus volume from a 0..1 linear slider value (what an options menu produces).
func set_bus_volume_linear(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("AudioManager: no bus named '%s'" % bus)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))

## Current bus volume as a 0..1 linear value (for initialising a slider).
func get_bus_volume_linear(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

## Mute / unmute a whole bus (e.g. a master mute toggle).
func set_bus_muted(bus: StringName, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

## --- Internals --------------------------------------------------------------

func _new_player_2d() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_SFX
	add_child(p)
	return p

func _new_player_3d() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SFX
	add_child(p)
	return p

## Grab a pooled 2D player that isn't currently playing; grow the pool if all busy.
func _free_player_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	var np := _new_player_2d()
	_pool_2d.append(np)
	return np

## Grab a pooled 3D player that isn't currently playing; grow the pool if all busy.
func _free_player_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var np := _new_player_3d()
	_pool_3d.append(np)
	return np

## Roll a random pitch within the def's range (defaults to 1.0 = no variation).
func _roll_pitch(def: Dictionary) -> float:
	var lo: float = def.get("pitch_min", 1.0)
	var hi: float = def.get("pitch_max", 1.0)
	if hi <= lo:
		return lo
	return randf_range(lo, hi)

## Turn on looping for whatever stream type this is (Ogg/MP3 vs WAV differ).
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
