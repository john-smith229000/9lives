extends SceneFlow
## Scene 6 — Day 1 vertical slice (greybox milestone).
##
## The day walks through EVERY time-of-day phase, one step per task done:
##   Morning  : wake at dawn beside the curled-up Friend (World fades in from black)
##   -> talk to James            -> Midday
##   -> nudge the ball           -> Afternoon
##   -> push the crate on its pad-> Evening (the Friend may curl up again)
##   -> come back beside the Friend; it curls up -> World.end_day():
##      Night falls, fade to black, loop counter advances, scene reloads -> same dawn.
##
## Order-tolerant: each beat no-ops if the player did it early (see SceneFlow.beat).
## The phase advances once per beat regardless of the order they finish in, so the day
## still passes through morning -> midday -> afternoon -> evening -> night.

## Quiet beat after waking before the first prompt/highlight appears, so James isn't
## outlined the instant the scene fades in.
const INTRO_DELAY := 4.0

func _run() -> void:
	var friend: Node3D = world.get_node_or_null("friend_cat")
	if friend == null:
		push_warning("scene6_flow: no 'friend_cat' node — nothing to run.")
		return
	var james: Node3D = world.get_node_or_null("James")
	var james_talk: Node = james.get_node_or_null("Talk") if james else null
	var ball: Node3D = world.first_ball()
	var crate: Node3D = world.first_crate()

	# Snapshot prop origins so "has it moved?" measures from the true start.
	mark_start(ball)
	mark_start(crate)

	# Live objectives (correct no matter when/if a beat was watching).
	objective(&"met_james", func() -> bool: return james_talk != null and james_talk.has_talked())
	objective(&"ball_pushed", func() -> bool: return has_moved(ball))
	objective(&"crate_on_goal", func() -> bool: return world.crate_goal_won())

	# If we've slept before, this dawn is a repeat — mark the loop landing.
	if GameState.current_day > 1:
		await wait(0.8)                              # let the fade-in settle
		await say("", ["Dawn. The same dawn — your friend, exactly as before."])
		GameState.set_flag(&"s6_loop_noticed")

	# Let the player wake and take in the morning before the first prompt lights up.
	await wait(INTRO_DELAY)

	# --- Midday: talk to James ---
	# highlight_scale matches James's hover outline thickness (char scale, not the
	# thicker prop scale used for the ball/crate).
	await beat({
		"objective": &"met_james", "highlight": james,
		"highlight_scale": Timing.char_outline_scale,
		"hint": "Talk to James by the harbor. [I]",
		"signal_obj": james_talk, "signal": &"talked",
	})
	GameState.set_flag(&"s6_met_james")
	world.set_time_phase(1)                          # Midday

	# --- Afternoon: nudge the ball ---
	await beat({"objective": &"ball_pushed", "highlight": ball,
		"hint": "Nudge that ball — just walk into it."})
	GameState.set_flag(&"s6_ball_pushed")
	world.set_time_phase(2)                          # Afternoon

	# --- Evening: push the crate onto its pad ---
	await beat({"objective": &"crate_on_goal", "highlight": crate,
		"hint": "Push the crate onto its pad."})
	GameState.set_flag(&"s6_crate_placed")
	world.set_time_phase(3)                          # Evening

	# --- Evening -> Night: rest beside the Friend ---
	hint("Evening. Return to your friend and rest.")
	if friend.has_method("enable_sleep"):
		friend.enable_sleep()                        # it may curl up again now
	await until(friend, &"curled_up")
	hide_hint()
	GameState.set_flag(&"s6_day1_done")

	await world.end_day()                            # Night, fade, loop back to dawn
