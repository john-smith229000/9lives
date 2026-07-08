extends Node
class_name InteractionController
## Handles talking to NPCs, three ways:
##   - Press Interact (I) while facing an Interactable  -> talk immediately.
##   - Hover an Interactable with the mouse             -> it gets an outline.
##   - Left-click a hovered Interactable                -> the cat walks up to face
##     them and, after a short beat, the conversation starts.
##
## Spawned by World after the camera, so its _unhandled_input runs first and can
## consume the Interact key (talking never doubles as a camera action).

var _world: Node
var _player: Node
var _camera: Node
var _cell := 1.0

# Hover / click-to-interact state.
var _hovered: Interactable = null   # under the mouse right now
var _lit: Node = null               # node currently outlined
var _pending: Interactable = null   # target we're walking to / waiting on
var _approach := Vector2i.ZERO      # tile we're walking to (next to the NPC)
var _state := 0                     # 0 = idle, 1 = chasing to NPC, 2 = waiting to talk
var _delay := 0.0
var _chase_target := Vector2i(-9999, -9999)   # NPC tile our current path aims next to

func setup(world: Node, player: Node, camera: Node, cell: float) -> void:
	_world = world
	_player = player
	_camera = camera
	_cell = cell
	_snap_interactables()

func _process(delta: float) -> void:
	# Hover only when idle and not mid-conversation.
	if _state == 0 and not Dialogue.is_active():
		_hovered = _hover_target()
	else:
		_hovered = null
	_update_walk_to_interact(delta)
	_update_outline()

# --- Interact key (immediate talk) ---------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if Dialogue.is_active():
		return                                  # the Dialogue autoload advances it
	var it := _facing_interactable()
	if it != null:
		get_viewport().set_input_as_handled()
		_talk_to(it)
	elif Dialogue.hint_visible():
		get_viewport().set_input_as_handled()
		Dialogue.hide_hint()                    # I also dismisses a standing hint

# --- Click to interact ----------------------------------------------------

## Called by World._on_click on a left click. If the mouse is over an NPC, start
## walking to them (and return true so the click isn't also click-to-move).
func try_click_interact() -> bool:
	if Dialogue.is_active():
		return false
	var it := _hover_target()
	if it == null:
		return false
	_begin_walk_to(it)
	return true

func _begin_walk_to(it: Interactable) -> void:
	_cancel()
	_pending = it
	_state = 1
	_chase_target = Vector2i(-9999, -9999)       # forces an immediate path on the first tick

## Prefer the tile in FRONT of the NPC (where they're looking) so the cat walks up
## face-to-face; fall back to the nearest reachable neighbour if that's blocked.
func _pick_approach(it: Interactable, npc_tile: Vector2i, start: Vector2i) -> Vector2i:
	var front: Vector2i = it.front_dir()
	if front != Vector2i.ZERO:
		var ft: Vector2i = npc_tile + front
		if ft == start:
			return ft
		if _world.path_walkable(ft) and not _world.find_path(start, ft).is_empty():
			return ft
	return _nearest_adjacent(start, npc_tile)

func _update_walk_to_interact(delta: float) -> void:
	if _state == 1:
		if _pending == null or not is_instance_valid(_pending):
			_cancel()
			return
		# Manual movement cancels the chase (but not while frozen for a bump line).
		if not Dialogue.is_active() and _player.has_method("is_manual_input") and _player.is_manual_input():
			_cancel()
			return
		var npc_tile: Vector2i = _pending.interact_tile(_cell)
		if _is_adjacent(_player.grid_tile(), npc_tile) and not _player.is_moving():
			_arrived_at_npc()
			return
		# Chase: (re)path toward a tile next to the NPC whenever it moves to a new
		# tile, or whenever we've stopped short of it. No stop condition — the player
		# cancels by moving (WASD) or clicking elsewhere.
		if npc_tile != _chase_target or not _player.is_moving():
			_chase_target = npc_tile
			var start: Vector2i = _player.nav_tile() if _player.has_method("nav_tile") else _player.grid_tile()
			var approach := _pick_approach(_pending, npc_tile, start)
			if approach.x >= 0 and approach != start:
				var path: Array = _world.find_path(start, approach)
				if not path.is_empty() and _player.has_method("set_path"):
					_player.set_path(path)
	elif _state == 2:
		_delay -= delta
		if _delay <= 0.0:
			_open_pending()

func _arrived_at_npc() -> void:
	# The NPC may have wandered off while we walked — only talk if it's next to us.
	if _pending == null or not _is_adjacent(_player.grid_tile(), _pending.interact_tile(_cell)):
		_cancel()
		return
	_state = 2
	_delay = Timing.interact_walk_delay
	if _player.has_method("face_tile"):
		_player.face_tile(_pending.interact_tile(_cell))

func _open_pending() -> void:
	if _pending == null or not is_instance_valid(_pending):
		_cancel()
		return
	# A conversation is already up (e.g. the NPC's "bump" line as it walked into us).
	# Keep the pending interaction and wait — then open the greeting right after.
	if Dialogue.is_active():
		return
	# Stepped away? Resume chasing rather than talking to empty air.
	if not _is_adjacent(_player.grid_tile(), _pending.interact_tile(_cell)):
		_state = 1
		_chase_target = Vector2i(-9999, -9999)
		return
	var it := _pending
	_cancel()
	_talk_to(it)

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

## Public: stop any in-progress walk-to-interact (a move-click cancels it).
func cancel() -> void:
	_cancel()

func _cancel() -> void:
	_pending = null
	_state = 0
	_chase_target = Vector2i(-9999, -9999)

# --- Shared talk + targeting ---------------------------------------------

func _talk_to(it: Interactable) -> void:
	if _player is Node3D:
		it.face_toward((_player as Node3D).global_position)
	Dialogue.start_speech(it.speaker_name(), it.get_lines(), Callable(it, "on_conversation_closed"), it.voice())

## The Interactable under the mouse (screen-space proximity to the body), or null.
func _hover_target() -> Interactable:
	var cam := _camera as Camera3D
	if cam == null:
		return null
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var radius := vp.get_visible_rect().size.y * Timing.interact_hover_radius
	var best: Interactable = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Interactable):
			continue
		var body: Vector3 = (node as Node3D).global_position + Vector3.UP * Timing.interact_hover_y
		if cam.is_position_behind(body):
			continue
		var sp := cam.unproject_position(body)
		var d := mouse.distance_to(sp)
		if d < best_d:
			best_d = d
			best = node
	return best

## The Interactable on the tile the cat faces (or, if it isn't facing anywhere
## yet, on any of the four neighbours), else null.
func _facing_interactable() -> Interactable:
	if _player == null:
		return null
	var base: Vector2i = _player.grid_tile()
	var facing: Vector2i = _player.facing_dir()
	var targets: Array = []
	if facing != Vector2i.ZERO:
		targets.append(base + facing)
	else:
		targets = [base + Vector2i.RIGHT, base + Vector2i.LEFT,
			base + Vector2i(0, 1), base + Vector2i(0, -1)]
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and (node.interact_tile(_cell) in targets):
			return node
	return null

## The walkable tile next to `goal` closest to `start` (or `start` if already
## adjacent), else (-1, -1).
func _nearest_adjacent(start: Vector2i, goal: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = goal + d
		if n == start:
			return start
		if not _world.path_walkable(n):
			continue
		var dist: int = absi(n.x - start.x) + absi(n.y - start.y)
		if dist < best_d:
			best_d = dist
			best = n
	return best

# --- Outline (hover + pending) -------------------------------------------

func _update_outline() -> void:
	var it: Interactable = _pending if _pending != null else _hovered
	if Dialogue.is_active():
		it = null
	# Outline just the character's MODEL subtree — not the whole owner (which also
	# holds the Talk node and any spawned arrow, which we don't want outlined).
	var vis: Node = null
	if it:
		var owner_node := it.get_parent()
		if owner_node and owner_node.has_node("Model"):
			vis = owner_node.get_node("Model")
		elif owner_node is Node3D:
			vis = owner_node
	if vis == _lit:
		return
	if _lit and is_instance_valid(_lit):
		Outline.remove(_lit)
	if vis:
		# Character outline: its own (thinner) thickness, steady (pulse_period 0).
		Outline.add(vis, Timing.outline_color, Timing.char_outline_scale, 1.0, 0.0)
	_lit = vis

# --- Setup ----------------------------------------------------------------

## Place each talkable NPC on its tile's ground surface (root Y = elevation +
## ground_y, matching how the roaming NPC sits).
func _snap_interactables() -> void:
	if _world == null or not _world.has_method("get_elevation"):
		return
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and node.snap_to_surface:
			var owner_node := node.get_parent()
			if owner_node is Node3D:
				var tile: Vector2i = node.interact_tile(_cell)
				var e: float = _world.get_elevation(tile.x, tile.y)
				var pos := (owner_node as Node3D).global_position
				pos.y = e + _world.ground_y
				(owner_node as Node3D).global_position = pos
