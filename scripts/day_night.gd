extends Node
class_name DayNightCycle
## Runs a level's gameplay-driven day/night cycle: eases the Sun light and the
## WorldEnvironment through a list of DayPhase presets. Created at runtime by World
## when day_night_enabled is on. Advances on the 'cycle_time' key (T).

var _sun: DirectionalLight3D
var _env: Environment
var _transition_time := 1.5
var _phases: Array[DayPhase] = []
var _index := 0
var _tween: Tween

## Wire up the nodes and presets (empty = built-in defaults) and set the opening
## time of day instantly.
func setup(sun: DirectionalLight3D, env: Environment, transition_time: float, phases: Array[DayPhase]) -> void:
	_sun = sun
	_env = env
	_transition_time = transition_time
	_phases = phases if not phases.is_empty() else _default_phases()
	if not _phases.is_empty():
		_apply_phase(_phases[_index], false)   # set the starting time instantly

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cycle_time"):
		advance()

## Advance to the next time of day and ease everything toward it.
func advance() -> void:
	if _phases.is_empty():
		return
	_index = (_index + 1) % _phases.size()
	_apply_phase(_phases[_index], true)

## Set (or tween) the sun and environment to a phase's look.
func _apply_phase(phase: DayPhase, animate: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate:
		if _sun:
			_sun.rotation_degrees = phase.sun_rotation
			_sun.light_energy = phase.sun_energy
			_sun.light_color = phase.sun_color
		if _env:
			_env.ambient_light_color = phase.ambient_color
			_env.ambient_light_energy = phase.ambient_energy
			_env.background_color = phase.sky_color
		return
	# Sunrise-style entry: snap the compass angle now (invisible while dark) so the
	# sun rises in place on this side instead of sweeping the long way around.
	if phase.snap_yaw_on_enter and _sun:
		_sun.rotation_degrees.y = phase.sun_rotation.y
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t := _transition_time
	if _sun:
		_tween.tween_property(_sun, "rotation_degrees", phase.sun_rotation, t)
		_tween.tween_property(_sun, "light_energy", phase.sun_energy, t)
		_tween.tween_property(_sun, "light_color", phase.sun_color, t)
	if _env:
		_tween.tween_property(_env, "ambient_light_color", phase.ambient_color, t)
		_tween.tween_property(_env, "ambient_light_energy", phase.ambient_energy, t)
		_tween.tween_property(_env, "background_color", phase.sky_color, t)

## Built-in phases used when the phase list is left empty. Afternoon matches the
## scene's default sun; morning mirrors it (sun low from the opposite side).
func _default_phases() -> Array[DayPhase]:
	var phases: Array[DayPhase] = []
	# Morning snaps its yaw on entry, so night -> morning rises on the East side
	# instead of the sun swinging all the way around.
	phases.append(_mk_phase("Morning", Vector3(-20, 120, 0), 0.55, Color(1.0, 0.85, 0.7), Color(0.60, 0.64, 0.72), 0.50, Color(0.74, 0.66, 0.60), true))
	phases.append(_mk_phase("Midday", Vector3(-78, -30, 0), 0.25, Color(1.0, 0.98, 0.95), Color(0.75, 0.80, 0.86), 0.60, Color(0.45, 0.64, 0.90)))
	phases.append(_mk_phase("Afternoon", Vector3(-50, -55, 0), 0.2, Color(1.0, 0.95, 0.85), Color(0.70, 0.78, 0.85), 0.55, Color(0.50, 0.66, 0.86)))
	phases.append(_mk_phase("Evening", Vector3(-12, -80, 0), 0.68, Color(1.0, 0.6, 0.36), Color(0.58, 0.48, 0.52), 0.55, Color(0.94, 0.55, 0.4)))
	# Night sits low on the West (where it set), so evening -> night just dims in
	# place; the swing to the East happens during the (dark) morning snap.
	phases.append(_mk_phase("Night", Vector3(-6, -100, 0), 0.10, Color(0.55, 0.65, 1.0), Color(0.22, 0.28, 0.45), 0.32, Color(0.06, 0.09, 0.20)))
	return phases

func _mk_phase(label: String, rot: Vector3, energy: float, col: Color, amb: Color, amb_e: float, sky: Color, snap_yaw := false) -> DayPhase:
	var p := DayPhase.new()
	p.label = label
	p.sun_rotation = rot
	p.sun_energy = energy
	p.sun_color = col
	p.ambient_color = amb
	p.ambient_energy = amb_e
	p.sky_color = sky
	p.snap_yaw_on_enter = snap_yaw
	return p
