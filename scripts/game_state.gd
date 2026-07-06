extends Node
## GameState — the persistent story record: which day it is and which story flags
## have been set. This is the SINGLE SOURCE OF TRUTH for "what has happened",
## deliberately kept SEPARATE from any scene's flow SCRIPT position.
##
## Why this exists: a SceneFlow used to be the only memory of the scene's progress,
## so if the player did things out of order (or a beat looked at the world too late)
## the script could get confused — highlight something already used, or wait forever
## on an action already performed. By recording facts here (and, for physical props,
## reading live world state), a flow can always ask "is this already done?" and stay
## correct no matter the order — or if the scene is reloaded mid-run.
##
## Registered as the "GameState" autoload (see project.godot).
##
## Flags are plain StringName keys. Use a scene prefix to keep them tidy, e.g.
## &"s1_villager_intro", &"s1_crate_crossed". current_day drives the 9-day loop.

## Emitted whenever a flag's value actually changes (not on redundant sets).
signal flag_changed(flag: StringName, value: bool)
## Emitted when the day advances (or on reset back to day 1).
signal day_changed(day: int)

## The current in-story day (1-based). The 9-day loop lives on top of this.
var current_day: int = 1

var _flags: Dictionary = {}   # StringName -> bool

## Set (or clear) a story flag. Emits flag_changed only on a real change, so it's
## safe to call every frame / every beat without spamming listeners.
func set_flag(flag: StringName, value: bool = true) -> void:
	var was: bool = _flags.get(flag, false)
	if was == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)

## Is a flag currently set? Unknown flags read as false.
func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false) == true

## Move to the next day (advances the 9-day loop).
func advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)

## Wipe all story state. Call this when starting a NEW game — NOT between scenes in
## the same run, and NOT on a retry/reload of the current scene (physical props reset
## themselves; story facts should persist across a run's scenes).
func reset() -> void:
	_flags.clear()
	current_day = 1
	day_changed.emit(current_day)
