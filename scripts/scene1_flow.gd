extends SceneFlow
## Scene 1's scripted beats, in order. This replaces the old guide.gd + the intro
## camera / ball-hint code that used to live in world.gd. Read it top-to-bottom.

const BALL_TIP := "Nudge a ball to roll it - just walk into it."

func _run() -> void:
	var villager: Node = world.get_node_or_null("Villager")
	var talk: Node = world.get_node_or_null("Villager/Talk")
	var ball: Node3D = world.first_ball()
	var crate: Node3D = world.first_crate()

	# Spotlight the ball and, concurrently, watch for the player to shove it: that
	# clears the hint and later floats an arrow over the villager (talk to clear it).
	if ball:
		highlight(ball)
		_ball_watch(ball, tile_of(ball), villager, talk)

	# Opening camera: linger on the cat, pan to the ball (show the tip), pan back.
	await wait(Timing.camera_pre_hold)
	if ball:
		camera_focus(ball)
		hint(BALL_TIP)
	await wait(Timing.camera_hold)
	camera_release()

	# Villager beat: first conversation -> spotlight a crate -> wait for the push
	# -> pause -> switch to the follow-up lines -> walk over to the ball goal.
	if talk:
		await until(talk, "talked")
	if crate:
		highlight(crate)
		await until_tile_changes(crate, tile_of(crate))
		unhighlight(crate)
	await wait()
	if talk and talk.has_method("use_after_lines"):
		talk.use_after_lines()
	if villager:
		await move_npc(villager, world.ball_goal_tile())

## Concurrent: once the ball is shoved, drop the hint/outline, then (after a beat)
## float an arrow over the villager until the player talks to them again.
func _ball_watch(ball: Node3D, from_tile: Vector2i, villager: Node, talk: Node) -> void:
	await until_tile_changes(ball, from_tile)
	unhighlight(ball)
	hide_hint()
	await wait(Timing.arrow_delay)
	var arrow: Node3D = null
	if villager is Node3D:
		arrow = spawn_arrow(villager)
	if talk:
		await until(talk, "conversation_ended")
	if arrow and is_instance_valid(arrow):
		arrow.queue_free()
