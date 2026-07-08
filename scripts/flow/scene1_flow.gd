extends SceneFlow
## Scene 1's scripted beats. Written to be ORDER-INDEPENDENT: the player can shove
## the ball, push the crate, or talk to the villager in any order (or ahead of the
## script) without stranding an outline or hanging the scene. Each beat asks "is this
## already done?" first (see beat() / objectives in scene_flow.gd), so it only ever
## sets up affordances for things still outstanding.
##
## Design note (adapt vs. prevent): we ADAPT to whatever the player already did and
## only prevent an action if doing it early would be UNRECOVERABLE. Here nothing is:
## the crate beat is satisfied by ANY move of the crate (measured from its start
## tile), so pushing it into the water still counts and never soft-locks. If you
## later decide the crate must reach a SPECIFIC spot (and water is a dead end), tie
## "crate_moved" to that tile instead and make the crate recoverable, or block that
## push in world.can_enter() gated on a GameState flag. See flow_system_spec.md.

const BALL_TIP := "Nudge a ball to roll it - just walk into it."

func _run() -> void:
	var villager: Node = world.get_node_or_null("Villager")
	var talk: Node = world.get_node_or_null("Villager/Talk")
	var ball: Node3D = world.first_ball()
	var crate: Node3D = world.first_crate()

	# Snapshot origins UP FRONT so "has it moved?" is measured from the true start,
	# even if the player shoves something before the beat that watches it.
	mark_start(ball)
	mark_start(crate)

	# Objectives are LIVE predicates over world state, so they're correct no matter
	# when (or whether) a beat was watching. This is what makes order not matter.
	objective(&"ball_shoved", func() -> bool: return has_moved(ball))
	objective(&"talked", func() -> bool: return talk != null and talk.has_talked())
	objective(&"crate_moved", func() -> bool: return has_moved(crate))

	# Highlight the ball up front (skip if the player already rolled it). The tip
	# itself appears later, synced to the camera pan below. The watcher owns clearing
	# both (no second beat re-shows them).
	var show_ball_intro := ball != null and not is_done(&"ball_shoved")
	if show_ball_intro:
		highlight(ball)

	# Ball watcher runs CONCURRENTLY (no await) with the villager beat, so the two are
	# order-independent relative to each other.
	_ball_beat(ball, villager, talk)

	# Opening camera: linger on the cat (camera_pre_hold), pan to the ball and show
	# the tip THEN, hold (camera_hold), pan back — original Timing preserved.
	if show_ball_intro:
		await wait(Timing.camera_pre_hold)
		camera_focus(ball)
		hint(BALL_TIP)
		await wait(Timing.camera_hold)
		camera_release()

	# Villager beat: talk -> spotlight the crate -> wait for it to be pushed.
	await beat({"objective": &"talked", "signal_obj": talk, "signal": &"talked"})
	GameState.set_flag(&"s1_villager_intro")

	await beat({"objective": &"crate_moved", "highlight": crate})
	GameState.set_flag(&"s1_crate_crossed")

	# Follow-up: switch the villager's lines, then walk them to the ball goal.
	await wait()
	if talk and talk.has_method("use_after_lines"):
		talk.use_after_lines()
	if villager:
		await move_npc(villager, world.ball_goal_tile())

## Concurrent: wait for the ball shove, then clear the opening tip + outline; then —
## unless the player has already talked — float an arrow over the villager until they
## do. Returns at once if the ball was already rolled (cleanup calls are no-ops).
func _ball_beat(ball: Node3D, villager: Node, talk: Node) -> void:
	await until_true(func() -> bool: return has_moved(ball))
	unhighlight(ball)
	hide_hint()
	GameState.set_flag(&"s1_ball_rolled")
	if is_done(&"talked"):
		return
	await wait(Timing.arrow_delay)
	if is_done(&"talked"):
		return
	await beat({
		"objective": &"talked", "signal_obj": talk, "signal": &"talked",
		"arrow": villager if villager is Node3D else null,
	})
