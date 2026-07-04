extends Node3D
## Builds the board from a beveled-tile set. Each tile picks the mesh + rotation
## that matches which of its edges are "free" (neighbour missing or lower), so
## flat same-height regions stay flush (no_bev) and only exposed edges are
## beveled. Also wires the player.

# Tile meshes (1 m cubes; bevels only on the listed FREE sides, in Godot axes).
const T_NO := preload("res://models/no_bev.glb")      # free: none
const T_ONE := preload("res://models/one_bev.glb")    # free: +Z
const T_TWO := preload("res://models/two_bev.glb")    # free: +X, +Z
const T_THREE := preload("res://models/three_bev.glb")# free: +X, -Z, +Z
const T_OPP := preload("res://models/two_opp_bev.glb")# free: -Z, +Z (opposite)
const T_FULL := preload("res://models/full_bev.glb")  # free: all

# Side bits used for matching/rotation. Cycle order E->N->W->S (a +90° Y turn
# shifts each side one step forward), so a rotation is a circular bit-shift.
const BIT_E := 1   # +X
const BIT_N := 2   # -Z
const BIT_W := 4   # -X
const BIT_S := 8   # +Z

@export var grid_size: int = 20
@export var cell_size: float = 1.0
@export var ground_y: float = 1.0
## When false, skip generating the tile terrain (use a custom map mesh instead).
@export var generate_terrain: bool = true
## Replace the beveled terrain tiles with plain flat-coloured boxes (same size and
## elevation). Simple, uniform look instead of the bevelled cube set.
@export var plain_box_tiles: bool = false
## Build the terrain as one continuous surface that slopes smoothly between tile
## heights (no stepped cube faces). Takes precedence over plain_box_tiles. Grid
## gameplay is unchanged; the surface just passes through each tile's height.
@export var smooth_terrain: bool = false
## Colour of the plain box / smooth terrain (the grassy top).
@export var tile_color: Color = Color("6a9b47")
## Colour of the smooth terrain's side-walls (the exposed dirt at edges, water and
## holes).
@export var terrain_side_color: Color = Color("5c4327")
## How far the smooth terrain's side-walls drop below the lowest ground (m).
@export var terrain_side_depth: float = 3.0
## Optional custom map node to auto-generate trimesh collision for (Scene 3).
@export var map_path: NodePath
## Force the map's materials fully matte (rough, non-metallic, no specular) so the
## ground has no shine/reflection.
@export var matte_ground: bool = false
## Optional node holding the buildings (separate meshes). When set, the keyhole
## see-through is applied ONLY to these meshes (so the map/floor stays solid),
## and trimesh collision is generated for them so the cat routes around them.
@export var buildings_path: NodePath

## Spawn one background NPC that walks back and forth along a clear lane (found
## automatically so it never starts in, or walks into, a building).
@export var npc_enabled: bool = false
## NPC walk speed (m/s), passed to the spawned NPC.
@export var npc_walk_speed: float = 1.6

@export_group("Terrain")
@export var height_gradient: float = 0.1
@export var noise_amplitude: float = 0.6
@export var noise_frequency: float = 0.16
@export var height_step: float = 0.1
@export var terrain_seed: int = 1337

@export_group("Pushable Blocks")
## Tiles (grid x, z) that start with a pushable block on them.
@export var block_tiles: Array[Vector2i] = [Vector2i(12, 10)]
## When true, a crate shoves the whole line of crates in front of it (a future
## experiment). Off by default: crates push one at a time.
@export var crates_chainable: bool = false

@export_group("Holes")
## Tiles (grid x, z) that hold a hole: the cat can't walk onto them, only jump
## over them to the tile beyond. The hole mesh's top sits at the lowest tile top.
@export var hole_tiles: Array[Vector2i] = []

@export_group("Water")
## Tiles (grid x, z) filled with water. Crates can be pushed in and float; the
## cat can't walk on or land on water.
@export var water_tiles: Array[Vector2i] = []
## Bob amplitude (m) right after a crate lands, the gentle amplitude it settles
## to, how fast it settles, and the bob frequency (Hz).
@export var water_bob_amplitude: float = 0.22
@export var water_bob_settle: float = 0.03
@export var water_bob_decay: float = 1.3
@export var water_bob_freq: float = 0.9
## How far (m) the water surface sits below the lowest tile top around the pond,
## so it recesses into the ground instead of poking above it.
@export var water_surface_drop: float = 0.1
## Max the crate dips BELOW its settled float during the bob, so it never sinks
## the crate top under the surface.
@export var water_bob_max_dip: float = 0.08
## Entry tip: how far the crate rotates as it plops in (radians), and how fast
## that settles back to level. Flip the sign to tip the other way.
@export var water_dive_angle: float = -0.35
@export var water_dive_decay: float = 2.5
## How quickly the crate eases down into the float (higher = snappier). Keeps the
## plop fluid instead of snapping to the surface.
@export var water_settle_rate: float = 5.0

@export_group("Grass")
## Grow grass on every generated ground tile (all the beveled terrain tiles),
## except holes and water. Use this for procedural-terrain scenes with no map.
@export var grass_on_all_tiles: bool = false
## Grow grass automatically wherever the map's painted colour matches (instead of
## listing tiles by hand). Samples the map's texture per tile.
@export var grass_from_paint: bool = false
## The painted colour that means "grass here".
@export var grass_paint_color: Color = Color("6a9b47")
## How close a tile's colour must be to count (0 = exact; raise if grass is
## missing, lower if it grows in the wrong places).
@export var grass_color_tolerance: float = 0.18
## Flip V when sampling the map texture (toggle if grass lands mirrored).
@export var grass_uv_flip_v: bool = false
## Tiles (grid x, z) that get grass — used only when grass_from_paint is off.
@export var grass_tiles: Array[Vector2i] = []
## Tufts scattered per grass tile.
@export var grass_per_tile: int = 120
## How far each blade wanders within its slot on the tile (0 = perfect grid,
## 1 = can reach neighbouring slots). Push toward 1 to break up the grid look.
@export var grass_jitter: float = 1.0
## Overall size multiplier on the model's native size (lower this if the tuft
## imported bigger than you want; 1.0 = original size).
@export var grass_scale: float = 0.14
## Per-blade height variation (0 = every blade the same height, 0.4 = ±40%). A
## ragged top surface reads far more natural than a uniform sheet of grass.
@export_range(0.0, 0.9) var grass_height_variation: float = 0.35
## Grass colour (the tips; roots are a touch darker).
@export var grass_color: Color = Color("6a9b47")
## How much blade normals lean toward straight up (0 = raw mesh, 1 = fully up).
## Higher stops thin blades self-shading to black under an overhead sun.
@export_range(0.0, 1.0) var grass_normal_up: float = 0.65
## Let grass cast shadows. Off avoids the shimmering self-shadow jitter that thin
## swaying blades cause in the directional shadow map (grass still receives them).
@export var grass_cast_shadows: bool = false
## Wind tip-sway distance (m) and speed.
@export var grass_wind_strength: float = 0.18
@export var grass_wind_speed: float = 1.8
## How out-of-phase neighbouring blades are. Higher makes the field ripple against
## itself (very visible) instead of leaning as one block.
@export var grass_sway_scale: float = 1.3
## Per-blade colour variation: warm/cool hue nudge, lighter/darker nudge, and slow
## field-scale patchiness. Small amounts read as natural; large gets noisy.
@export var grass_hue_variation: float = 0.035
@export var grass_brightness_variation: float = 0.12
@export var grass_patch_variation: float = 0.08
## How strongly the blade tips look sunlit (warmer/lighter). 0 = off.
@export_range(0.0, 1.0) var grass_tip_kiss: float = 1.0
## Softens the lighting so the shadow side of the field lifts to dim grass instead
## of a flat dark mass. 0 = hard/normal lighting, 1 = fully soft. Works from any
## camera angle (unlike a backlight glow, which needs to face the sun).
@export_range(0.0, 1.0) var grass_shadow_lift: float = 0.5
## How far flattened blades push over.
@export var grass_bend_strength: float = 2.0
## Seconds a flattened blade takes to spring back upright after the cat leaves.
## Each blade fades on its own timer, so higher = a longer-lingering wake.
@export var grass_recovery: float = 3.5
## Seconds for grass to press flat once stepped on (so a landing eases in rather
## than snapping down all at once).
@export var grass_press_time: float = 0.12
## Radius (m) of the pressed footprint under the cat: blades right under it flatten
## fully, easing to none at this distance. Smaller = more concentrated in the tile
## centre and less overall deformation.
@export var grass_footprint: float = 0.6

@export_group("Hints")
## Spotlight the first ball at level start (outline + camera pan) until it's
## shoved for the first time.
@export var hint_ball_at_start: bool = false
## Seconds the camera lingers on the hinted ball before panning back to the cat.
@export var hint_camera_hold: float = 1.6
## Outline colour and hull size (relative; 1.06 = 6% larger = thicker outline).
@export var hint_outline_color: Color = Color(1.0, 0.92, 0.25)
@export var hint_outline_scale: float = 1.06
## Outline opacity pulse: dimmest alpha, and seconds per fade in+out cycle.
@export var hint_outline_pulse_min: float = 0.60
@export var hint_outline_pulse_period: float = 2.5

@export_group("Day/Night")
## Enable a gameplay-driven day/night cycle. Advance time with the 'cycle_time'
## key (T) for testing.
@export var day_night_enabled: bool = false
## Seconds for the eased transition when time advances.
@export var day_transition_time: float = 1.5
## Ordered presets (morning -> night). Leave empty to use built-in defaults.
@export var day_phases: Array[DayPhase] = []

@export_group("Rolling Balls")
## Tiles (grid x, z) that start with a rollable ball on them.
@export var ball_tiles: Array[Vector2i] = [Vector2i(7, 10)]
## Speed (m/s) a ball gets when the cat shoves it.
@export var ball_launch_speed: float = 4.5
## Energy cost per tile on flat ground — lower = rolls farther.
@export var ball_friction: float = 2.5
## How much each tile of elevation change adds/removes from the roll distance
## (uphill shortens it, downhill lengthens it).
@export var ball_slope_accel: float = 12.0

@export_group("Keyhole See-Through")
## Soft-circle x-ray so the cat shows through buildings that occlude it.
@export var enable_keyhole: bool = true
## Circle size as a fraction of screen height.
@export var keyhole_radius: float = 0.09
## Feather width at the circle's edge.
@export var keyhole_softness: float = 0.00
## Opacity at the center of the circle (0 = fully see-through). Low = clearest
## view of the cat; density ramps up toward the circle's edge.
@export var keyhole_min_alpha: float = 0.04
## Metres a surface must be in front of the cat before it dissolves. 0 = the
## whole circle dissolves anything closer to the camera than the cat (uniform).
@export var keyhole_depth_bias: float = 0.0
## Hard dot-free zone radius (screen-height fraction). Pixels within this
## distance of the player are always fully discarded — no dither at all.
## Good value: roughly 0.5–0.7 * keyhole_radius.
@export var keyhole_clear_radius: float = 0.14

const _KEYHOLE_SHADER: Shader = preload("res://shaders/keyhole.gdshader")
const _NPC_SCENE: PackedScene = preload("res://scenes/npc.tscn")
var _npc_spawned := false
var _npc_walk_set: Dictionary = {}   # Vector2i -> true, tiles the NPC may stand on
var _npc_walk_list: Array[Vector2i] = []   # same tiles, for random picks
# One entry per building mesh: {node, mats:[ShaderMaterial], aabb:AABB, active:float}.
# `active` eases toward 1 while the building sits between the camera and the cat.
var _keyhole_buildings: Array = []
# While inside (free mode) we strip the keyhole materials so the building renders
# with its original material (spotlight, culling, etc. all behave normally).
var _keyhole_inside := false

var _heights: Array = []
var _noise: FastNoiseLite
var _defs: Array = []           # [{scene, mask, top}]
var _box_tile_mesh: BoxMesh     # shared mesh+material for plain_box_tiles
var _blocks: Dictionary = {}    # Vector2i(tile) -> block Node3D
var _holes: Dictionary = {}     # Vector2i(tile) -> hole Node3D (jump-over gaps)
var _water: Dictionary = {}     # Vector2i(tile) -> water Node3D
var _water_stack: Dictionary = {}  # Vector2i(water tile) -> [crate nodes], bottom->top
var _water_surface := 0.5       # flat world Y of the water top
var _block_water: Dictionary = {}  # crate instance_id -> seconds afloat (for the bob)
var _block_water_dir: Dictionary = {}  # crate instance_id -> Vector2i it was shoved in
var _block_starts: Array = []   # [{block, tile}] for restart
var _block_bottom := -0.375     # crate's lowest point relative to its origin
var _block_height := 0.75       # crate height (AABB span), for mounting on top
var _crate_scene: PackedScene

# --- Goals ---
# Each goal: {tile, untriggered, triggered, bottom, tri_bottom, h_unt, h_tri,
#             node, won, by ("crate"/"ball"), pad_extra}
var _goals: Array = []
var _player_start := Vector3.ZERO   # cat's start position, for Restart

# --- Balls ---
var _ball_scene: PackedScene
var _balls: Array = []          # [{node, dir, speed, resting, tile, start}]
var _ball_radius := 0.375

# --- Hint (spotlight an object until interacted with) ---
var _hint_ball_node: Node3D = null
var _hint_cam_timer := 0.0

# --- Grass ---
var _grass_mats: Array[ShaderMaterial] = []   # one per blade mesh
var _grass_mms: Array = []                    # the MultiMeshes (for writing per-blade custom data)
# Per-blade bookkeeping (indexed by a global blade id).
var _grass_blade_mm: PackedInt32Array = PackedInt32Array()   # which MultiMesh
var _grass_blade_idx: PackedInt32Array = PackedInt32Array()  # instance index inside it
var _grass_blade_pos: PackedVector3Array = PackedVector3Array()
var _grass_bins: Dictionary = {}              # tile -> Array of blade ids near it
var _grass_active: Dictionary = {}            # blade id -> Vector3(bend, dir.x, dir.z) for blades still recovering

@onready var _grid_root: Node3D = $Grid
@onready var _player: CharacterBody3D = $Player
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = get_node_or_null("Camera")
@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")

# --- Day/night ---
var _day_index := 0
var _day_tween: Tween

var _obstacle: Dictionary = {}   # cached map-feature blocked tiles (lazy)
var _obstacle_built := false

func _ready() -> void:
	if _sun:
		_sun.rotation_degrees = Vector3(-50.0, -55.0, 0.0)
	_build_grid()
	_build_map_collision()
	_build_buildings_collision()
	if matte_ground:
		_matte_map()
	_spawn_blocks()
	_spawn_goal()
	_spawn_balls()
	_spawn_holes()
	_spawn_water()
	_spawn_grass()
	if _player:
		_player.grid_size = grid_size
		_player.cell_size = cell_size
		_player.ground_y = ground_y
		_player.height_provider = Callable(self, "get_elevation")
		_player.block_handler = Callable(self, "can_enter")
		_player.occupied_provider = Callable(self, "_is_pushable_tile")
		_player.surface_provider = Callable(self, "surface_elevation")
		_player.block_provider = Callable(self, "has_block")
		_player.hole_provider = Callable(self, "has_hole")
		_player.water_provider = Callable(self, "has_water")
		_player.view_camera = _camera
		_player.sync_to_grid()
		_player_start = _player.global_position
	_setup_click_catcher()
	if enable_keyhole:
		_apply_keyhole()
	if hint_ball_at_start and not _balls.is_empty():
		_start_ball_hint()
	if day_night_enabled:
		if day_phases.is_empty():
			day_phases = _default_day_phases()
		_apply_phase(day_phases[_day_index], false)   # set the starting time instantly

## Generate trimesh collision for a custom map mesh (Scene 3) so grid movement
## is blocked by its walls/features.
func _build_map_collision() -> void:
	if map_path == NodePath(""):
		return
	var map := get_node_or_null(map_path)
	if map == null:
		push_warning("World: map_path '%s' not found — no map collision generated." % str(map_path))
		return
	var meshes := _all_mesh_instances(map)
	if meshes.is_empty():
		push_warning("World: map has no MeshInstance3D to build collision from.")
	print("[map] generating collision for ", meshes.size(), " mesh(es) under ", map_path)
	for mi in meshes:
		(mi as MeshInstance3D).create_trimesh_collision()

## Force every material on the map fully matte: rough, non-metallic, no specular
## and no reflections, so the ground has zero shine. Duplicates each material so
## only this scene's ground is affected.
func _matte_map() -> void:
	var map := get_node_or_null(map_path)
	if map == null:
		return
	for node in _all_mesh_instances(map):
		var mi := node as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var src: Material = mi.get_active_material(s)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
				m.metallic = 0.0
				m.roughness = 1.0
				m.metallic_specular = 0.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(s, m)

## Generate trimesh collision for the separate building meshes so the cat is
## blocked by them (the map mesh is now just the floor).
func _build_buildings_collision() -> void:
	if buildings_path == NodePath(""):
		return
	var buildings := get_node_or_null(buildings_path)
	if buildings == null:
		return
	var meshes := _all_mesh_instances(buildings)
	print("[buildings] generating collision for ", meshes.size(), " mesh(es) under ", buildings_path)
	for mi in meshes:
		(mi as MeshInstance3D).create_trimesh_collision()

func _build_grid() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = terrain_seed
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	# Canonical free-edge masks for each tile (from the Blender orientation).
	_defs = [
		{"scene": T_NO, "mask": 0},
		{"scene": T_ONE, "mask": BIT_S},
		{"scene": T_TWO, "mask": BIT_E | BIT_S},
		{"scene": T_THREE, "mask": BIT_E | BIT_N | BIT_S},
		{"scene": T_OPP, "mask": BIT_N | BIT_S},
		{"scene": T_FULL, "mask": BIT_E | BIT_N | BIT_W | BIT_S},
	]
	for d in _defs:
		d["top"] = _measure_top(d["scene"])

	# Pass 1: heights (flat when terrain generation is off, e.g. a custom map).
	_heights.resize(grid_size)
	for x in grid_size:
		var column: Array = []
		column.resize(grid_size)
		for z in grid_size:
			column[z] = _elevation_for(x, z) if generate_terrain else 0.0
		_heights[x] = column

	# Pass 2: place the ground (skipped for custom maps).
	if generate_terrain:
		if smooth_terrain:
			_build_smooth_terrain()
		else:
			for x in grid_size:
				for z in grid_size:
					if Vector2i(x, z) in hole_tiles or Vector2i(x, z) in water_tiles:
						continue      # hole/water mesh replaces the ground cube here
					_place_tile(x, z)

func _place_tile(x: int, z: int) -> void:
	var e: float = float(_heights[x][z])
	var top := e + 0.5

	if plain_box_tiles:
		_place_box_tile(x, z, top)
		return

	# Which sides are free (neighbour missing or strictly lower).
	var mask := 0
	if _is_free(top, x + 1, z): mask |= BIT_E   # +X
	if _is_free(top, x, z - 1): mask |= BIT_N   # -Z
	if _is_free(top, x - 1, z): mask |= BIT_W   # -X
	if _is_free(top, x, z + 1): mask |= BIT_S   # +Z

	# Find the tile + rotation whose beveled edges match this pattern.
	var scene: PackedScene = T_FULL          # fallback (shouldn't trigger now)
	var rot := 0
	var mesh_top: float = _defs[_defs.size() - 1]["top"]   # T_FULL is last
	for d in _defs:
		var matched := false
		for k in 4:
			if _rotl(d["mask"], k) == mask:
				scene = d["scene"]
				rot = k
				mesh_top = d["top"]
				matched = true
				break
		if matched:
			break

	var container := Node3D.new()
	var inst := scene.instantiate()
	container.add_child(inst)
	# (No material override — let each glb keep its own baked materials/colors.)
	# Align this mesh's own top to the tile surface so all tops are flush and the
	# cat's feet land correctly, regardless of tile type.
	container.position = Vector3(x * cell_size, top - mesh_top, z * cell_size)
	container.rotation.y = deg_to_rad(90.0 * rot)
	# Tiny X/Z overlap so flush neighbour walls don't z-fight.
	container.scale = Vector3(1.01, 1.0, 1.01)
	_grid_root.add_child(container)

## Place a plain flat-coloured 1 m box in place of a bevelled tile. The mesh and
## material are shared across every tile. `top` is the tile's surface height.
func _place_box_tile(x: int, z: int, top: float) -> void:
	if _box_tile_mesh == null:
		_box_tile_mesh = BoxMesh.new()
		_box_tile_mesh.size = Vector3(cell_size, 1.0, cell_size)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tile_color
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_box_tile_mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _box_tile_mesh
	mi.position = Vector3(x * cell_size, top - 0.5, z * cell_size)
	mi.scale = Vector3(1.01, 1.0, 1.01)   # tiny overlap so flush walls don't z-fight
	_grid_root.add_child(mi)

## Build the terrain as one continuous surface. Each tile gets a full-size top
## quad from its four shared corner heights (so the ground covers whole tiles and
## slopes smoothly between them), plus dirt side-walls dropped wherever it borders
## the map edge, water, or a hole — so those read as banks/pits, not floating cuts.
func _build_smooth_terrain() -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var min_h := INF
	for x in grid_size:
		for z in grid_size:
			min_h = minf(min_h, float(_heights[x][z]))
	if is_inf(min_h):
		min_h = 0.0
	var base_y := min_h + 0.5 - terrain_side_depth   # how far the side-walls drop
	for x in grid_size:
		for z in grid_size:
			if not _is_ground(x, z):
				continue
			# Smooth top quad (corners shared with neighbours -> continuous surface).
			_tri(top, x, z, x, z + 1, x + 1, z + 1)
			_tri(top, x, z, x + 1, z + 1, x + 1, z)
			# Side-walls on edges facing a non-ground tile.
			if not _is_ground(x - 1, z): _wall(wall, x, z + 1, x, z, base_y, Vector3(-1, 0, 0))
			if not _is_ground(x + 1, z): _wall(wall, x + 1, z, x + 1, z + 1, base_y, Vector3(1, 0, 0))
			if not _is_ground(x, z - 1): _wall(wall, x, z, x + 1, z, base_y, Vector3(0, 0, -1))
			if not _is_ground(x, z + 1): _wall(wall, x + 1, z + 1, x, z + 1, base_y, Vector3(0, 0, 1))
	_add_terrain_surface(top, tile_color)
	_add_terrain_surface(wall, terrain_side_color)

## True when a tile is on the grid and is neither a hole nor water (i.e. has ground).
func _is_ground(x: int, z: int) -> bool:
	if x < 0 or x >= grid_size or z < 0 or z >= grid_size:
		return false
	var t := Vector2i(x, z)
	return not (t in hole_tiles) and not (t in water_tiles)

## One top-surface triangle from three grid corners, with slope-following normals.
func _tri(st: SurfaceTool, ax: int, az: int, bx: int, bz: int, cx: int, cz: int) -> void:
	st.set_normal(_corner_normal(ax, az)); st.add_vertex(_corner_pos(ax, az))
	st.set_normal(_corner_normal(bx, bz)); st.add_vertex(_corner_pos(bx, bz))
	st.set_normal(_corner_normal(cx, cz)); st.add_vertex(_corner_pos(cx, cz))

## A vertical wall quad from two top corners down to base_y, facing `n`.
func _wall(st: SurfaceTool, ax: int, az: int, bx: int, bz: int, base_y: float, n: Vector3) -> void:
	var ta := _corner_pos(ax, az)
	var tb := _corner_pos(bx, bz)
	var ba := Vector3(ta.x, base_y, ta.z)
	var bb := Vector3(tb.x, base_y, tb.z)
	for v in [ta, ba, bb, ta, bb, tb]:
		st.set_normal(n)
		st.add_vertex(v)

## World position of grid corner (i, j) — the shared corner between up to four
## tiles — at the average height of the ground tiles that meet there.
func _corner_pos(i: int, j: int) -> Vector3:
	return Vector3((i - 0.5) * cell_size, _corner_y(i, j), (j - 0.5) * cell_size)

func _corner_y(i: int, j: int) -> float:
	return _corner_y_or(i, j, 0.0)

## Average surface height of the ground tiles meeting at corner (i, j); `fallback`
## when none (used so edge normals don't get skewed by off-map corners).
func _corner_y_or(i: int, j: int, fallback: float) -> float:
	var sum := 0.0
	var n := 0
	for t in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
		if _is_ground(t.x, t.y):
			sum += _heights[t.x][t.y] + 0.5
			n += 1
	return sum / float(n) if n > 0 else fallback

## Smooth up-facing normal from neighbouring corner heights.
func _corner_normal(i: int, j: int) -> Vector3:
	var c := _corner_y(i, j)
	var dx := _corner_y_or(i - 1, j, c) - _corner_y_or(i + 1, j, c)
	var dz := _corner_y_or(i, j - 1, c) - _corner_y_or(i, j + 1, c)
	return Vector3(dx, 2.0 * cell_size, dz).normalized()

## Commit a terrain SurfaceTool as a matte, double-sided MeshInstance of `col`.
func _add_terrain_surface(st: SurfaceTool, col: Color) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_grid_root.add_child(mi)

func _is_free(top: float, nx: int, nz: int) -> bool:
	var nt := _tile_top(nx, nz)
	return is_nan(nt) or nt < top - 0.001

func _tile_top(x: int, z: int) -> float:
	if x < 0 or x >= grid_size or z < 0 or z >= grid_size:
		return NAN
	return float(_heights[x][z]) + 0.5

## Circular left-shift of the 4-bit side mask by k (one step = a +90° Y turn).
func _rotl(mask: int, k: int) -> int:
	for _i in k:
		mask = ((mask << 1) | (mask >> 3)) & 0xF
	return mask

## Top Y of a tile mesh in its own local space (after its baked root scale).
func _measure_top(scene: PackedScene) -> float:
	var inst := scene.instantiate()
	add_child(inst)
	var mi := _find_mesh_instance(inst)
	var t := 0.5
	if mi:
		t = (mi.global_transform * mi.get_aabb()).end.y - global_position.y
	inst.queue_free()
	return t

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found := _find_mesh_instance(c)
		if found:
			return found
	return null

func _elevation_for(x: int, z: int) -> float:
	var slope := float((grid_size - 1 - x) + (grid_size - 1 - z)) * height_gradient
	var n := (_noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5) * noise_amplitude
	var ev := maxf(slope + n, 0.0)
	if height_step > 0.0:
		ev = roundf(ev / height_step) * height_step
	return ev

## Elevation (meters) of a tile's top surface above the base. Used by the player.
## Includes the goal pad's current height so the cat / crate stand on top of it.
func get_elevation(x: int, z: int) -> float:
	if x >= 0 and x < grid_size and z >= 0 and z < grid_size:
		# A crate floating in water is a platform: stand on its LIVE top so the cat
		# rides the bob with it.
		if _water.has(Vector2i(x, z)) and _blocks.has(Vector2i(x, z)):
			var fb: Node3D = _blocks[Vector2i(x, z)]
			return (fb.position.y + _block_bottom + _block_height) - 0.5
		var e: float = _heights[x][z]
		for goal in _goals:
			if goal["tile"].x == x and goal["tile"].y == z:
				e += goal["pad_extra"]
		return e
	return 0.0

## Standing-surface elevation of a tile, INCLUDING a crate sitting on it, so a
## jump can land on the crate top. (Balls aren't mountable.) Used by the player
## for jump resolution; plain walking still uses get_elevation (terrain only).
func surface_elevation(x: int, z: int) -> float:
	var e := get_elevation(x, z)
	# On land, standing surface is the crate top. In water the crate floats and
	# get_elevation already gives its top, so don't add its height again.
	if _blocks.has(Vector2i(x, z)) and not _water.has(Vector2i(x, z)):
		e += _block_height
	return e

## Is there a pushable crate on this tile? (Lets the player decide to mount it.)
func has_block(tile: Vector2i) -> bool:
	return _blocks.has(tile)

# --- Holes (jump-over gaps) -----------------------------------------------

## Place the hole mesh on each hole tile. The model is authored with its top at
## +0.5 (a tile top), so we sit it at the lowest tile elevation — its top then
## lines up with the lowest 1 m cube tops and it drops into a pit below.
func _spawn_holes() -> void:
	if hole_tiles.is_empty():
		return
	var scene: PackedScene = load("res://models/hole.glb")
	if scene == null:
		push_warning("World: could not load hole.glb")
		return
	var mesh_top := _measure_top(scene)   # align the hole's rim to the ground surface
	for tile in hole_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		if _holes.has(tile):
			continue
		var node := scene.instantiate() as Node3D
		var surf := float(_heights[tile.x][tile.y]) + 0.5   # this tile's own top
		node.position = Vector3(tile.x * cell_size, surf - mesh_top, tile.y * cell_size)
		_grid_root.add_child(node)
		_holes[tile] = node

## Is there a hole on this tile? The cat can't walk onto it, only jump over it.
func has_hole(tile: Vector2i) -> bool:
	return _holes.has(tile)

# --- Water ----------------------------------------------------------------

## Fill each water tile with a water cube on one flat surface (the lowest water
## tile's top), so higher ground reads as banks. Crates float here; the cat can't.
func _spawn_water() -> void:
	if water_tiles.is_empty():
		return
	var scene: PackedScene = load("res://models/water.glb")
	if scene == null:
		push_warning("World: could not load water.glb")
		return
	# Surface sits just below the lowest tile top of the pond AND its banks, so it
	# never rides above the surrounding terrain.
	var min_elev := INF
	var around := [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for t in water_tiles:
		for d in around:
			var n: Vector2i = t + d
			if n.x >= 0 and n.x < grid_size and n.y >= 0 and n.y < grid_size:
				min_elev = minf(min_elev, float(_heights[n.x][n.y]))
	if is_inf(min_elev):
		min_elev = 0.0
	_water_surface = min_elev + 0.5 - water_surface_drop
	for tile in water_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		if _water.has(tile):
			continue
		var node := scene.instantiate() as Node3D
		# The water cube's top is at +0.5 locally; sit it so the top is at surface.
		node.position = Vector3(tile.x * cell_size, _water_surface - 0.5, tile.y * cell_size)
		_grid_root.add_child(node)
		_water[tile] = node

## Is there water on this tile? The cat can't walk onto or land on it.
func has_water(tile: Vector2i) -> bool:
	return _water.has(tile)

# --- Grass (wind-swaying blades) ------------------------------------------

## Scatter single grass blades (models/blade1.glb .. blade5.glb, one picked at
## random per blade) over the grass tiles, driven by the wind shader. A MultiMesh
## holds a single mesh, so there's one MultiMesh per blade variant. Blade height
## is measured from each model, so it isn't set by hand.
func _spawn_grass() -> void:
	var tiles: Array[Vector2i]
	if grass_on_all_tiles:
		tiles = _grass_all_ground_tiles()
	elif grass_from_paint:
		tiles = _grass_tiles_from_paint()
	else:
		tiles = grass_tiles
	if tiles.is_empty():
		return
	var meshes := _blade_meshes()
	if meshes.is_empty():
		push_warning("World: no blade meshes (models/blade1.glb ...) found — no grass.")
		return
	var rng := RandomNumberGenerator.new()
	# One transform list per blade variant.
	var lists: Array = []
	for _m in meshes:
		lists.append([])
	for tile in tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		var top := get_elevation(tile.x, tile.y) + 0.5
		# Stratified placement: one blade per cell of a sub-grid across the tile
		# (with jitter), so coverage is even instead of randomly clumped.
		var cols := maxi(int(ceil(sqrt(float(grass_per_tile)))), 1)
		var sub := cell_size / float(cols)
		var origin_x := tile.x * cell_size - cell_size * 0.5
		var origin_z := tile.y * cell_size - cell_size * 0.5
		for i in grass_per_tile:
			var cx := origin_x + (float(i % cols) + 0.5) * sub
			var cz := origin_z + (float(i / cols) + 0.5) * sub
			# Independent XZ and Y scale: vary height more than width so the top of
			# the field is ragged (breaks the uniform-sheet / grid look).
			var sxz := grass_scale * rng.randf_range(0.85, 1.15)
			var sy := grass_scale * maxf(0.3, 1.0 + rng.randf_range(-grass_height_variation, grass_height_variation))
			var t := Transform3D.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU)
			t = t.scaled(Vector3(sxz, sy, sxz))
			var wx := cx + rng.randf_range(-0.5, 0.5) * sub * grass_jitter
			var wz := cz + rng.randf_range(-0.5, 0.5) * sub * grass_jitter
			# Sit each blade on the actual (interpolated) surface so grass hugs
			# slopes instead of stepping at tile centres.
			t.origin = Vector3(wx, _grass_surface_y(wx, wz, top), wz)
			(lists[rng.randi() % meshes.size()] as Array).append(t)
	_grass_mats.clear()
	_grass_mms.clear()
	_grass_blade_mm = PackedInt32Array()
	_grass_blade_idx = PackedInt32Array()
	_grass_blade_pos = PackedVector3Array()
	_grass_bins.clear()
	_grass_active.clear()
	for k in meshes.size():
		var xforms: Array = lists[k]
		if xforms.is_empty():
			continue
		var mesh: Mesh = meshes[k]
		var blade_h: float = maxf(mesh.get_aabb().size.y, 0.01)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true     # per-blade bend amount + push direction
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		var mm_index := _grass_mms.size()
		for i in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))   # start un-bent
			# Record this blade so we can stamp it when the cat walks near.
			var gid := _grass_blade_mm.size()
			_grass_blade_mm.append(mm_index)
			_grass_blade_idx.append(i)
			_grass_blade_pos.append(xf.origin)
			var btile := Vector2i(roundi(xf.origin.x / cell_size), roundi(xf.origin.z / cell_size))
			var bin: Array = _grass_bins.get(btile, [])
			bin.append(gid)
			_grass_bins[btile] = bin
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# Thin, swaying blades make the directional shadow map shimmer (worst at
		# noon when they're edge-on to the sun). Off by default kills that jitter;
		# grass still receives shadows from buildings.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if grass_cast_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _grass_material(blade_h)
		mmi.material_override = mat
		_grass_mats.append(mat)
		_grass_mms.append(mm)
		_grid_root.add_child(mmi)

## The mesh from each of models/blade1.glb .. blade5.glb that exists.
func _blade_meshes() -> Array:
	var out: Array = []
	for i in range(1, 6):
		var path := "res://models/blade%d.glb" % i
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		for mi in _all_mesh_instances(inst):
			out.append((mi as MeshInstance3D).mesh)
			break
		inst.queue_free()
	return out

## Every generated ground tile (holes and water have no ground cube, so skip them).
func _grass_all_ground_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in grid_size:
		for z in grid_size:
			var t := Vector2i(x, z)
			if t in hole_tiles or t in water_tiles:
				continue
			out.append(t)
	return out

## Surface height at an arbitrary world XZ. On smooth terrain this bilinearly
## interpolates the corner heights (so grass hugs the slope); otherwise the tile's
## flat top (`fallback`) is used.
func _grass_surface_y(wx: float, wz: float, fallback: float) -> float:
	if not smooth_terrain:
		return fallback
	var tx := roundi(wx / cell_size)
	var tz := roundi(wz / cell_size)
	var u := clampf(wx / cell_size - float(tx) + 0.5, 0.0, 1.0)
	var v := clampf(wz / cell_size - float(tz) + 0.5, 0.0, 1.0)
	var a := lerpf(_corner_y(tx, tz), _corner_y(tx + 1, tz), u)
	var b := lerpf(_corner_y(tx, tz + 1), _corner_y(tx + 1, tz + 1), u)
	return lerpf(a, b, v)

func _grass_material(blade_h: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/grass_wind.gdshader")
	m.set_shader_parameter("blade_height", blade_h)
	m.set_shader_parameter("tip_color", grass_color)
	m.set_shader_parameter("base_color", grass_color.darkened(0.18))
	m.set_shader_parameter("normal_up", grass_normal_up)
	m.set_shader_parameter("wind_strength", grass_wind_strength)
	m.set_shader_parameter("wind_speed", grass_wind_speed)
	m.set_shader_parameter("sway_scale", grass_sway_scale)
	m.set_shader_parameter("hue_variation", grass_hue_variation)
	m.set_shader_parameter("brightness_variation", grass_brightness_variation)
	m.set_shader_parameter("patch_variation", grass_patch_variation)
	# Sun-kissed tips: lighter + warmer (more red/green, less blue) than the tips.
	var kiss := grass_color.lightened(0.3)
	kiss.r = minf(1.0, kiss.r + 0.10)
	kiss.g = minf(1.0, kiss.g + 0.06)
	kiss.b = maxf(0.0, kiss.b - 0.04)
	m.set_shader_parameter("tip_highlight", kiss)
	m.set_shader_parameter("tip_kiss", grass_tip_kiss)
	m.set_shader_parameter("shadow_lift", grass_shadow_lift)
	m.set_shader_parameter("bend_strength", grass_bend_strength)
	return m

## Which tiles are painted the grass colour on the map's texture. For each tile
## centre we find the map triangle under it, read its UV, sample the texture, and
## keep the tile if the colour is close to grass_paint_color.
func _grass_tiles_from_paint() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var map := get_node_or_null(map_path)
	if map == null:
		push_warning("World: grass_from_paint needs a map_path.")
		return out
	var mi: MeshInstance3D = null
	for m in _all_mesh_instances(map):
		mi = m
		break
	if mi == null or mi.mesh == null:
		return out
	var img := _albedo_image(mi)
	if img == null:
		push_warning("World: map material has no readable albedo texture for grass_from_paint.")
		return out
	var mesh: Mesh = mi.mesh
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if verts.is_empty() or uvs.is_empty():
		push_warning("World: map mesh has no UVs; can't sample paint for grass.")
		return out
	var xf: Transform3D = mi.global_transform
	# Precompute each vertex's world XZ (the plane we test tile centres against).
	var wxz := PackedVector2Array()
	wxz.resize(verts.size())
	for vi in verts.size():
		var wp: Vector3 = xf * verts[vi]
		wxz[vi] = Vector2(wp.x, wp.z)
	var tri_n: int = (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
	var iw := float(img.get_width())
	var ih := float(img.get_height())
	for x in grid_size:
		for z in grid_size:
			var uv := _uv_at_point(Vector2(x * cell_size, z * cell_size), wxz, uvs, idx, tri_n)
			if uv.x < -0.5:
				continue
			var u := clampf(uv.x, 0.0, 1.0)
			var v := clampf(uv.y, 0.0, 1.0)
			if grass_uv_flip_v:
				v = 1.0 - v
			var px := clampi(int(u * (iw - 1.0)), 0, img.get_width() - 1)
			var py := clampi(int(v * (ih - 1.0)), 0, img.get_height() - 1)
			if _color_close(img.get_pixel(px, py), grass_paint_color, grass_color_tolerance):
				out.append(Vector2i(x, z))
	return out

## Barycentric UV of point p (world XZ) inside the first map triangle containing
## it; returns (-1,-1) if no triangle covers it.
func _uv_at_point(p: Vector2, wxz: PackedVector2Array, uvs: PackedVector2Array, idx: PackedInt32Array, tri_n: int) -> Vector2:
	for ti in tri_n:
		var i0: int
		var i1: int
		var i2: int
		if idx.size() > 0:
			i0 = idx[ti * 3]; i1 = idx[ti * 3 + 1]; i2 = idx[ti * 3 + 2]
		else:
			i0 = ti * 3; i1 = ti * 3 + 1; i2 = ti * 3 + 2
		var a := wxz[i0]
		var b := wxz[i1]
		var c := wxz[i2]
		if p.x < minf(a.x, minf(b.x, c.x)) - 0.001 or p.x > maxf(a.x, maxf(b.x, c.x)) + 0.001:
			continue
		if p.y < minf(a.y, minf(b.y, c.y)) - 0.001 or p.y > maxf(a.y, maxf(b.y, c.y)) + 0.001:
			continue
		var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(d) < 0.0000001:
			continue
		var w0 := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
		var w1 := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
		var w2 := 1.0 - w0 - w1
		if w0 >= -0.01 and w1 >= -0.01 and w2 >= -0.01:
			return uvs[i0] * w0 + uvs[i1] * w1 + uvs[i2] * w2
	return Vector2(-1.0, -1.0)

func _color_close(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol

func _albedo_image(mi: MeshInstance3D) -> Image:
	var mat := mi.get_active_material(0)
	if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture:
		var img: Image = (mat as BaseMaterial3D).albedo_texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			return img
	return null

# --- Pushable blocks ------------------------------------------------------

func _spawn_blocks() -> void:
	if block_tiles.is_empty():
		return
	_crate_scene = load("res://models/crate.glb")
	if _crate_scene == null:
		push_warning("World: could not load crate.glb")
		return
	_block_bottom = _measure_block_bottom()
	for tile in block_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		if _blocks.has(tile):
			continue
		var block := _make_crate()
		block.position = _block_world_pos(tile)
		_grid_root.add_child(block)
		_blocks[tile] = block
		_block_starts.append({"block": block, "tile": tile})

## crate.glb currently holds the whole Blender scene, so pull out just the node
## named "crate" and drop everything else (the tiles / grass cubes).
func _make_crate() -> Node3D:
	var src := _crate_scene.instantiate()
	var holder := Node3D.new()
	var crate := src.find_child("crate", true, false)
	if crate:
		crate.get_parent().remove_child(crate)
		crate.owner = null            # avoid the reparent/owner-inconsistency warning
		holder.add_child(crate)
	else:
		push_warning("World: no 'crate' node inside crate.glb")
	src.queue_free()
	return holder

## The crate's lowest point relative to its origin, so we can rest it on a tile.
func _measure_block_bottom() -> float:
	var inst := _make_crate()
	add_child(inst)
	var min_y := INF
	var max_y := -INF
	for mi in _all_mesh_instances(inst):
		var m := mi as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb()
		min_y = minf(min_y, box.position.y)
		max_y = maxf(max_y, box.position.y + box.size.y)
	inst.queue_free()
	if not is_inf(min_y) and not is_inf(max_y):
		_block_height = max_y - min_y     # crate's full vertical span
	return -0.375 if is_inf(min_y) else min_y - global_position.y

func _all_mesh_instances(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_all_mesh_instances(c, acc)
	return acc

## Send every block back to the tile it started on (used by the Restart button).
func reset_blocks() -> void:
	_blocks.clear()
	_water_stack.clear()
	_block_water.clear()
	_block_water_dir.clear()
	for s in _block_starts:
		var block: Node3D = s["block"]
		var tile: Vector2i = s["tile"]
		block.position = _block_world_pos(tile)
		block.rotation = Vector3.ZERO
		_blocks[tile] = block
	# Reset every goal back to its un-triggered state.
	for goal in _goals:
		if goal["won"]:
			goal["won"] = false
			_place_goal(goal, false)
	# Reset balls to their start tiles, stationary.
	for ball in _balls:
		ball["resting"] = true
		ball["speed"] = 0.0
		ball["dir"] = Vector2i.ZERO
		ball["tile"] = ball["start"]
		var node: Node3D = ball["node"]
		node.position = _ball_world_pos(ball["start"])
		node.rotation = Vector3.ZERO
	# Reset the cat back to its starting position.
	if _player and _player.has_method("reset_to_start"):
		_player.reset_to_start(_player_start)
	# Swing the camera back to the default orientation.
	if _camera and _camera.has_method("reset_rotation"):
		_camera.reset_rotation()

func _block_world_pos(tile: Vector2i) -> Vector3:
	# Rest the crate's bottom on the tile's top surface (tile top = elevation + 0.5).
	var surface := get_elevation(tile.x, tile.y) + 0.5
	return Vector3(tile.x * cell_size, surface - _block_bottom, tile.y * cell_size)

# --- Click to move -------------------------------------------------------

# A full-screen Control captures clicks: its local mouse position and size are
# in the same coordinate space, sidestepping the project_ray stretch bug.
func _setup_click_catcher() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1                       # below the pause menu
	add_child(layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(catcher)
	catcher.gui_input.connect(_on_click.bind(catcher))

func _on_click(event: InputEvent, catcher: Control) -> void:
	if _camera == null or _player == null:
		return
	if _player.has_method("is_in_free_mode") and _player.is_in_free_mode():
		return                               # interior uses free WASD, not click
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var tile := _click_to_tile(event.position, catcher.size)
	if tile.x < 0:
		return
	var start: Vector2i = _player.nav_tile() if _player.has_method("nav_tile") else _player_tile()
	if not _player.has_method("set_path"):
		return

	# Push/interact gesture: if the cat is right next to a crate/ball and you
	# click straight past it (same row or column, that direction), walk straight
	# INTO it to push/shove rather than pathfinding around.
	var delta := tile - start
	if delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0):
		var dir := Vector2i(signi(delta.x), signi(delta.y))
		if _is_pushable_tile(start + dir):
			_player.set_path(_straight_line(start, dir, tile))
			return

	# Otherwise pathfind around obstacles.
	var path := find_path(start, tile)
	if not path.is_empty():
		_player.set_path(path)

func _is_pushable_tile(tile: Vector2i) -> bool:
	return _blocks.has(tile) or not _ball_at(tile).is_empty()

## Straight cardinal line of tiles from start (exclusive) toward target, used for
## push gestures so the path runs through the object instead of around it.
func _straight_line(start: Vector2i, dir: Vector2i, target: Vector2i) -> Array:
	var path: Array = []
	var c := start
	while c != target:
		c += dir
		if c.x < 0 or c.x >= grid_size or c.y < 0 or c.y >= grid_size:
			break
		path.append(c)
	return path

## Unproject a click (Control-local pos within `screen_size`) and return the tile
## it lands on. Manual ortho unprojection (immune to the project_ray stretch bug)
## plus a height-field raymarch so it's correct over elevated terrain too.
func _click_to_tile(local_pos: Vector2, screen_size: Vector2) -> Vector2i:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector2i(-1, -1)
	var ndc := Vector2(local_pos.x / screen_size.x, local_pos.y / screen_size.y) * 2.0 - Vector2.ONE
	var cam := _camera.global_transform
	var half_h := _camera.size * 0.5
	var half_w := half_h * (screen_size.x / screen_size.y)
	var origin := cam.origin + cam.basis.x * (ndc.x * half_w) + cam.basis.y * (-ndc.y * half_h)
	var fwd := -cam.basis.z
	if absf(fwd.y) < 0.00001:
		return Vector2i(-1, -1)
	# March the ray down through the terrain; stop at the first tile whose top
	# surface (elevation + 0.5) the ray drops to or below.
	var step := 0.15
	var p := origin
	for _i in 1200:
		p += fwd * step
		var tx := roundi(p.x / cell_size)
		var tz := roundi(p.z / cell_size)
		if tx >= 0 and tx < grid_size and tz >= 0 and tz < grid_size:
			if p.y <= get_elevation(tx, tz) + 0.5:
				return Vector2i(tx, tz)
		if p.y < -5.0:
			break
	return Vector2i(-1, -1)

## BFS over walkable tiles. Returns the list of tiles from the first step to the
## goal (cardinal-adjacent), or [] if unreachable.
func find_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	_ensure_obstacles()
	if not _path_walkable(goal):
		return []
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var found := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for d in dirs:
			var n: Vector2i = cur + d
			if came.has(n) or not _path_walkable(n):
				continue
			came[n] = cur
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var c := goal
	while c != start:
		path.push_front(c)
		c = came[c]
	return path

func _path_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return false
	if _water.has(tile):
		return _blocks.has(tile)     # only a floating crate is walkable
	if _blocks.has(tile) or _holes.has(tile):
		return false
	for ball in _balls:
		if ball["resting"] and ball["tile"] == tile:
			return false
	return not _obstacle.has(tile)

## Cache which tiles are blocked by static geometry (house walls, map features),
## once, using the cat's own collision so it matches what blocks movement.
func _ensure_obstacles() -> void:
	if _obstacle_built:
		return
	if _player == null or not _player.has_method("is_tile_blocked"):
		_obstacle_built = true
		return
	if get_world_3d().direct_space_state == null:
		return                                # physics not ready yet — retry next click
	_obstacle_built = true
	for x in grid_size:
		for z in grid_size:
			if _player.is_tile_blocked(Vector2i(x, z)):
				_obstacle[Vector2i(x, z)] = true

# --- Background NPC -------------------------------------------------------

## Spawn one roaming NPC. Deferred until physics is ready (obstacle probe + floor
## rays need the space state), so this is polled from _process until it succeeds.
func _try_spawn_npc() -> void:
	if get_world_3d().direct_space_state == null:
		return                                # physics not ready — retry next frame
	_ensure_obstacles()
	if not _obstacle_built:
		return
	_build_npc_walkable()
	if _npc_walk_list.is_empty():
		_npc_spawned = true                   # nowhere to walk; don't retry
		push_warning("World: no walkable tiles found for the NPC.")
		return
	var start: Vector2i = _npc_walk_list[randi() % _npc_walk_list.size()]
	var npc := _NPC_SCENE.instantiate()
	add_child(npc)
	npc.setup_roam(self, start, cell_size, ground_y, npc_walk_speed)
	_npc_spawned = true

## World position for the NPC to stand on a tile (matches the cat's ride height).
func _npc_world(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * cell_size, ground_y, tile.y * cell_size)

## A tile the NPC may stand on: not a static obstacle (building/wall) AND with
## floor beneath it (so it never wanders onto an off-map edge).
func _npc_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return false
	if _obstacle.has(tile):
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var w := Vector3(tile.x * cell_size, 0.0, tile.y * cell_size)
	var params := PhysicsRayQueryParameters3D.create(
		Vector3(w.x, ground_y + 5.0, w.z), Vector3(w.x, ground_y - 2.0, w.z))
	return not space.intersect_ray(params).is_empty()

## Build the set/list of tiles the NPC may stand on (once), so roaming and its
## pathfinding are cheap lookups instead of per-tile raycasts.
func _build_npc_walkable() -> void:
	_npc_walk_set.clear()
	_npc_walk_list.clear()
	for x in grid_size:
		for z in grid_size:
			var t := Vector2i(x, z)
			if _npc_walkable(t):
				_npc_walk_set[t] = true
				_npc_walk_list.append(t)

## A random tile the NPC can stand on (for picking roam destinations).
func npc_random_tile() -> Vector2i:
	if _npc_walk_list.is_empty():
		return Vector2i(-1, -1)
	return _npc_walk_list[randi() % _npc_walk_list.size()]

## BFS over NPC-walkable tiles (routes around buildings and off-map gaps).
## Returns tiles from the first step to goal (cardinal-adjacent), or [] if
## unreachable. Used by the roaming NPC.
func npc_find_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal or not _npc_walk_set.has(goal):
		return []
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var found := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for d in dirs:
			var n: Vector2i = cur + d
			if came.has(n) or not _npc_walk_set.has(n):
				continue
			came[n] = cur
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var c := goal
	while c != start:
		path.push_front(c)
		c = came[c]
	return path

## Called by the player: can it step onto `tile` moving in `dir`?
## Returns true (free), false (blocked), or {block, from, to} when a block is
## being pushed — the player then slides that block in lockstep with itself.
func can_enter(tile: Vector2i, dir: Vector2i) -> Variant:
	# A hole can't be walked onto (only jumped over).
	if _holes.has(tile):
		return false
	# Water: empty water blocks; a LONE floating crate is a platform to walk onto;
	# a STACK (2+) gets its top crate shoved off to the next tile as the cat steps
	# down onto the base.
	if _water.has(tile):
		if not _blocks.has(tile):
			return false
		if _water_stack.get(tile, []).size() <= 1:
			return true                       # lone floating crate -> mount it
		return _shove_stack_top(tile, dir)    # stacked -> shove the top off
	# A ball (rolling or resting): (re)shove it and step into the tile it vacates.
	var ball := _ball_at(tile)
	if not ball.is_empty():
		return _launch_ball(ball, dir)
	if not _blocks.has(tile):
		return true
	# Pushing a land crate. Chaining a whole line at once is a future experiment.
	var line: Array[Vector2i] = [tile]
	if crates_chainable:
		var c := tile + dir
		while _blocks.has(c):
			line.append(c)
			c += dir
	var beyond: Vector2i = line[line.size() - 1] + dir
	if beyond.x < 0 or beyond.x >= grid_size or beyond.y < 0 or beyond.y >= grid_size:
		return false
	if _holes.has(beyond) or not _ball_at(beyond).is_empty():
		return false
	if _blocks.has(beyond):
		# Destination occupied: only a single crate pushed onto a LONE floating
		# crate stacks on top of it; anything else is blocked.
		if not crates_chainable and _water.has(beyond) and _water_stack.get(beyond, []).size() == 1:
			var pb: Node3D = _blocks[tile]
			_remove_crate(pb, tile)
			_add_crate(pb, beyond)
			_block_water_dir[pb.get_instance_id()] = dir
			return {"blocks": [{"block": pb, "from": pb.position, "to": _block_world_pos(beyond)}]}
		return false
	# Shift the crate(s) one tile (far crate first so occupancy stays valid).
	var pushes: Array = []
	for i in range(line.size() - 1, -1, -1):
		var from_tile: Vector2i = line[i]
		var to_tile: Vector2i = from_tile + dir
		var blk: Node3D = _blocks[from_tile]
		_remove_crate(blk, from_tile)
		_add_crate(blk, to_tile)
		if _water.has(to_tile):
			_block_water_dir[blk.get_instance_id()] = dir   # for the entry-dive tip
		pushes.append({"block": blk, "from": blk.position, "to": _block_world_pos(to_tile)})
	return {"blocks": pushes}

## Shove the top crate of a stacked water tile onto `tile + dir` (a new lone
## floating crate, or a land crate), letting the cat step onto the base. Returns
## the push for the player to drive, or false if there's nowhere to shove it.
func _shove_stack_top(tile: Vector2i, dir: Vector2i) -> Variant:
	var dest := tile + dir
	if dest.x < 0 or dest.x >= grid_size or dest.y < 0 or dest.y >= grid_size:
		return false
	if _holes.has(dest) or _blocks.has(dest) or not _ball_at(dest).is_empty():
		return false
	var stack: Array = _water_stack[tile]
	var top: Node3D = stack[stack.size() - 1]
	_remove_crate(top, tile)                  # pop it off the stack (base remains)
	_add_crate(top, dest)                     # floats at dest (or lands on ground)
	if _water.has(dest):
		_block_water_dir[top.get_instance_id()] = dir
	return {"blocks": [{"block": top, "from": top.position, "to": _block_world_pos(dest)}]}

## Add a crate onto a tile, tracking bottom->top stacks on water tiles.
func _add_crate(blk: Node3D, tile: Vector2i) -> void:
	if _water.has(tile):
		var s: Array = _water_stack.get(tile, [])
		s.append(blk)
		_water_stack[tile] = s
		_blocks[tile] = s[s.size() - 1]       # _blocks tracks the top crate
	else:
		_blocks[tile] = blk

## Remove a crate from a tile, updating the water stack / occupancy.
func _remove_crate(blk: Node3D, tile: Vector2i) -> void:
	if _water_stack.has(tile):
		var s: Array = _water_stack[tile]
		s.erase(blk)
		if s.is_empty():
			_water_stack.erase(tile)
			_blocks.erase(tile)
		else:
			_water_stack[tile] = s
			_blocks[tile] = s[s.size() - 1]
	elif _blocks.get(tile) == blk:
		_blocks.erase(tile)

# --- Goal ----------------------------------------------------------------

func _spawn_goal() -> void:
	# Crate-triggered goal (only where there's a crate), and a ball-triggered one.
	if not block_tiles.is_empty():
		_add_goal("res://models/goal_tile.glb", "res://models/goal_tile_triggered.glb", "crate")
	if not ball_tiles.is_empty():
		_add_goal("res://models/goal_tile_b.glb", "res://models/goal_tile_b_triggered.glb", "ball")

func _add_goal(unt_path: String, tri_path: String, by: String) -> void:
	var unt: PackedScene = load(unt_path)
	var tri: PackedScene = load(tri_path)
	if unt == null or tri == null:
		push_warning("World: goal glb(s) missing for " + by)
		return
	var a0 := _measure_aabb_y(unt)
	var a1 := _measure_aabb_y(tri)
	var goal := {
		"tile": _pick_goal_tile(), "untriggered": unt, "triggered": tri,
		"bottom": a0.x, "tri_bottom": a1.x,
		"h_unt": a0.y - a0.x, "h_tri": a1.y - a1.x,
		"node": null, "won": false, "by": by, "pad_extra": 0.0,
	}
	_goals.append(goal)
	_place_goal(goal, false)

## A random tile not used by the player, crates, balls, or an existing goal.
func _pick_goal_tile() -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed + 7
	var player_tile := Vector2i(10, 10)
	if _player:
		player_tile = Vector2i(roundi(_player.global_position.x / cell_size), roundi(_player.global_position.z / cell_size))
	for _i in 200:
		var t := Vector2i(rng.randi_range(0, grid_size - 1), rng.randi_range(0, grid_size - 1))
		if t == player_tile or t in block_tiles or t in ball_tiles:
			continue
		var clash := false
		for g in _goals:
			if g["tile"] == t:
				clash = true
				break
		if not clash:
			return t
	return Vector2i(0, 0)

func _place_goal(goal: Dictionary, triggered: bool) -> void:
	if goal["node"]:
		(goal["node"] as Node3D).queue_free()
	var scene: PackedScene = goal["triggered"] if triggered else goal["untriggered"]
	var node := scene.instantiate() as Node3D
	var tile: Vector2i = goal["tile"]
	# Raw terrain height (not get_elevation, which adds the pad) so the pad rests
	# on the ground rather than floating on its own height.
	var surface := float(_heights[tile.x][tile.y]) + 0.5
	var bottom: float = goal["tri_bottom"] if triggered else goal["bottom"]
	node.position = Vector3(tile.x * cell_size, surface - bottom, tile.y * cell_size)
	_grid_root.add_child(node)
	goal["node"] = node
	# Things standing on the tile ride on top of the pad at its current height.
	goal["pad_extra"] = goal["h_tri"] if triggered else goal["h_unt"]

func _process(delta: float) -> void:
	_update_goal()
	_update_crate_heights(delta)
	_update_balls(delta)
	_update_keyhole(delta)
	if npc_enabled and not _npc_spawned:
		_try_spawn_npc()
	# After lingering on a hinted object, pan the camera back to the cat (the
	# outline stays until the object is actually interacted with).
	if _hint_cam_timer > 0.0:
		_hint_cam_timer -= delta
		if _hint_cam_timer <= 0.0 and _camera and _camera.has_method("release_focus"):
			_camera.release_focus()
	if day_night_enabled and Input.is_action_just_pressed("cycle_time"):
		_advance_day()
	if not _grass_active.is_empty() or (not _grass_bins.is_empty() and _player):
		_update_grass(delta)

## Per-blade grass wake: fade any flattened blades on their own timer, then stamp
## the grass on the tile the cat is standing on. Only tiles the cat actually steps
## on flatten, and each recovers independently — so walking leaves a settling
## trail of footprints, with no radius/sphere and no travelling wave.
func _update_grass(delta: float) -> void:
	var fade := delta / maxf(grass_recovery, 0.05)
	# 1) Fade every still-recovering blade toward upright.
	var dead: Array = []
	for gid in _grass_active:
		var e: Vector3 = _grass_active[gid]
		e.x -= fade
		if e.x <= 0.0:
			dead.append(gid)
			_write_blade(gid, 0.0, Vector2.ZERO)
		else:
			_grass_active[gid] = e
			_write_blade(gid, e.x, Vector2(e.y, e.z))
	for gid in dead:
		_grass_active.erase(gid)
	# 2) Press the grass on the tile under the cat toward flat — splayed away from
	# it, easing in over grass_press_time so a landing doesn't snap down at once.
	# Skip while airborne so a jump only flattens its takeoff and landing tiles,
	# not every tile the arc flies over.
	if _player == null:
		return
	if _player.has_method("is_airborne") and _player.is_airborne():
		return
	var p := _player.global_position
	var ptile := Vector2i(roundi(p.x / cell_size), roundi(p.z / cell_size))
	var press := delta / maxf(grass_press_time, 0.01)
	var falloff := maxf(grass_footprint, 0.05)
	var bin: Array = _grass_bins.get(ptile, [])
	for gid in bin:
		var bp: Vector3 = _grass_blade_pos[gid]
		var off := Vector2(bp.x - p.x, bp.z - p.z)
		var d := off.length()
		# Full press right under the cat, easing to none at the footprint edge —
		# so the deformation stays concentrated where the cat actually is.
		var target := clampf(1.0 - d / falloff, 0.0, 1.0)
		if target <= 0.0:
			continue
		var dir := off.normalized() if d > 0.0001 else Vector2(0, 1)
		var cur: float = (_grass_active[gid] as Vector3).x if _grass_active.has(gid) else 0.0
		var amt := minf(cur + press, target) if cur < target else cur
		_grass_active[gid] = Vector3(amt, dir.x, dir.y)
		_write_blade(gid, amt, dir)

## Write one blade's bend amount + push direction into its MultiMesh custom data.
func _write_blade(gid: int, bend: float, dir: Vector2) -> void:
	var mm: MultiMesh = _grass_mms[_grass_blade_mm[gid]]
	mm.set_instance_custom_data(_grass_blade_idx[gid],
		Color(bend, dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, 0.0))

# --- Keyhole see-through --------------------------------------------------

## Register each building mesh with its own keyhole material(s) + world bounds.
## If buildings_path is set we target ONLY that node (map/floor stays solid).
## Otherwise we fall back to the rest of the scene (minus terrain & cat).
func _apply_keyhole() -> void:
	_keyhole_buildings.clear()
	var roots: Array = []
	if buildings_path != NodePath(""):
		var buildings := get_node_or_null(buildings_path)
		if buildings:
			roots.append(buildings)
		else:
			push_warning("World: buildings_path '%s' not found." % str(buildings_path))
	else:
		for child in get_children():
			if child == _grid_root or child == _player:
				continue   # skip terrain + dynamic objects and the cat
			roots.append(child)
	for r in roots:
		for mi in _all_mesh_instances(r):
			_keyhole_register(mi as MeshInstance3D)

func _keyhole_register(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var mats: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := ShaderMaterial.new()
		mat.shader = _KEYHOLE_SHADER
		var orig := mi.get_active_material(i)
		if orig is BaseMaterial3D:
			mat.set_shader_parameter("albedo_color", (orig as BaseMaterial3D).albedo_color)
			var tex := (orig as BaseMaterial3D).albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_tex", tex)
				mat.set_shader_parameter("use_tex", true)
		mat.set_shader_parameter("radius", keyhole_radius)
		mat.set_shader_parameter("softness", keyhole_softness)
		mat.set_shader_parameter("min_alpha", keyhole_min_alpha)
		mat.set_shader_parameter("depth_bias", keyhole_depth_bias)
		mat.set_shader_parameter("clear_radius", keyhole_clear_radius)
		mat.set_shader_parameter("active", 0.0)
		mi.set_surface_override_material(i, mat)
		mats.append(mat)
	# World-space bounds, used to test whether the camera->cat line passes through
	# this building (i.e. it's actually occluding the cat).
	var world_aabb: AABB = mi.global_transform * mi.get_aabb()
	_keyhole_buildings.append({"node": mi, "mats": mats, "aabb": world_aabb, "active": 0.0})

## Swap the keyhole shader on (true) or restore each building's original glb
## material (false, used while inside in free mode).
func _set_keyhole_materials(enabled: bool) -> void:
	for b in _keyhole_buildings:
		var mi = b["node"]
		if not is_instance_valid(mi):
			continue
		var mats: Array = b["mats"]
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i] if enabled else null)

## Feed the cat's screen position to every building, and switch each building's
## effect on/off depending on whether it actually sits between camera and cat.
func _update_keyhole(delta: float) -> void:
	if _keyhole_buildings.is_empty() or _camera == null or _player == null:
		return
	# When the cat steps inside (free mode) we render the building with its
	# ORIGINAL material so its lighting (spotlight), culling, etc. all behave;
	# the keyhole shader only goes back on once we're outside in the iso view.
	var inside: bool = _player.has_method("is_in_free_mode") and _player.is_in_free_mode()
	if inside != _keyhole_inside:
		_keyhole_inside = inside
		_set_keyhole_materials(not inside)
	if inside:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var pw := _player.global_position
	pw.y -= 0.1   # aim at the cat's body
	var screen := _camera.unproject_position(pw)
	var su := Vector2(screen.x / vp.x, screen.y / vp.y)
	# Horizontal-only look direction so a tall wall behind the cat doesn't read as
	# "in front" just because it's high.
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.0001:
		fwd = fwd.normalized()
	var asp := vp.x / vp.y
	# Sample lines from the camera to points along the cat's VERTICAL axis only
	# (feet / middle / head). Staying on the cat's exact x,z means these lines
	# can't reach a wall behind the cat, so a building only activates when it's
	# truly between the camera and the cat — not one the cat is standing before.
	var cam_pos := _camera.global_position
	var foot := _player.global_position
	var targets: Array[Vector3] = [
		foot + Vector3(0.0, 0.05, 0.0),
		foot + Vector3(0.0, 0.45, 0.0),
		foot + Vector3(0.0, 0.85, 0.0),
	]
	var ease_w := 1.0 - exp(-14.0 * delta)
	for b in _keyhole_buildings:
		var aabb: AABB = b["aabb"]
		var occluding := false
		# Skip occlusion if the cat is inside/under this building's bounding box —
		# the AABB test would fire even through open arches or when walking inside.
		if not aabb.has_point(foot):
			for t in targets:
				if aabb.intersects_segment(cam_pos, t):
					occluding = true
					break
		var target := 1.0 if occluding else 0.0
		b["active"] = lerpf(float(b["active"]), target, ease_w)
		for m in b["mats"]:
			m.set_shader_parameter("player_screen", su)
			m.set_shader_parameter("player_world", pw)
			m.set_shader_parameter("cam_forward", fwd)
			m.set_shader_parameter("aspect", asp)
			m.set_shader_parameter("active", b["active"])
			m.set_shader_parameter("radius", keyhole_radius)
			m.set_shader_parameter("softness", keyhole_softness)
			m.set_shader_parameter("min_alpha", keyhole_min_alpha)
			m.set_shader_parameter("depth_bias", keyhole_depth_bias)
			m.set_shader_parameter("clear_radius", keyhole_clear_radius)

## Keep each crate sitting on whatever surface is under it (ground, or the goal
## pad at its current height), easing the Y so it rides the pad / smush smoothly.
## The player drives crate X/Z while pushing; World owns the Y.
func _update_crate_heights(delta: float) -> void:
	for tile in _blocks:
		if _water.has(tile):
			_float_stack(tile, delta)
		else:
			var b: Node3D = _blocks[tile]
			var tx := roundi(b.position.x / cell_size)
			var tz := roundi(b.position.z / cell_size)
			var id := b.get_instance_id()
			if _block_water.has(id):
				_block_water.erase(id)          # left the water; reset the bob
				_block_water_dir.erase(id)
			var target_y := (get_elevation(tx, tz) + 0.5) - _block_bottom
			b.position.y = lerpf(b.position.y, target_y, 1.0 - exp(-15.0 * delta))

## Position a water tile's crate stack: the bottom floats with a decaying bob
## (0.1 m of its top above the surface), and each crate above rides on the one
## below. Entry eases in so it drops fluidly.
func _float_stack(tile: Vector2i, delta: float) -> void:
	var stack: Array = _water_stack.get(tile, [])
	if stack.is_empty():
		return
	var float_y := (_water_surface + 0.1) - (_block_bottom + _block_height)
	for idx in range(stack.size()):
		var crate: Node3D = stack[idx]
		# Float/ride only once the crate is physically over the water tile, so a
		# crate being shoved in slides to the edge at ground height, THEN drops in.
		var ctx := roundi(crate.position.x / cell_size)
		var ctz := roundi(crate.position.z / cell_size)
		if Vector2i(ctx, ctz) != tile:
			var gy := (get_elevation(ctx, ctz) + 0.5) - _block_bottom
			crate.position.y = lerpf(crate.position.y, gy, 1.0 - exp(-15.0 * delta))
			continue
		if idx == 0:
			# Bottom: float with a decaying bob + an entry-dive that eases to level.
			var id := crate.get_instance_id()
			var t: float = float(_block_water.get(id, 0.0)) + delta
			_block_water[id] = t
			var amp := water_bob_settle + (water_bob_amplitude - water_bob_settle) * exp(-water_bob_decay * t)
			var off := maxf(amp * sin(TAU * water_bob_freq * t), -water_bob_max_dip)
			crate.position.y = lerpf(crate.position.y, float_y + off, 1.0 - exp(-water_settle_rate * delta))
			var edir: Vector2i = _block_water_dir.get(id, Vector2i.ZERO)
			var dive := water_dive_angle * exp(-water_dive_decay * t)
			var er := Vector3.ZERO
			if edir.x != 0:
				er.z = float(edir.x) * dive
			elif edir.y != 0:
				er.x = float(edir.y) * dive
			crate.rotation = crate.rotation.lerp(er, 1.0 - exp(-10.0 * delta))
		else:
			# Rides on the crate below (and levels out).
			crate.position.y = lerpf(crate.position.y, stack[idx - 1].position.y + _block_height, 1.0 - exp(-water_settle_rate * delta))
			crate.rotation = crate.rotation.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))

## Toggle each goal by how much its triggering object (crate or ball) covers it.
## Triggers at ~40% coverage, releases below 30% (hysteresis avoids flicker).
func _update_goal() -> void:
	for goal in _goals:
		if goal["node"] == null:
			continue
		var tile: Vector2i = goal["tile"]
		var gx := tile.x * cell_size
		var gz := tile.y * cell_size
		var best := 0.0
		if goal["by"] == "ball":
			for ball in _balls:
				var n: Node3D = ball["node"]
				best = maxf(best, clampf(1.0 - Vector2(n.position.x - gx, n.position.z - gz).length() / cell_size, 0.0, 1.0))
		else:
			for bt in _blocks:
				var b: Node3D = _blocks[bt]
				best = maxf(best, clampf(1.0 - Vector2(b.position.x - gx, b.position.z - gz).length() / cell_size, 0.0, 1.0))
		if not goal["won"] and best >= 0.4:
			goal["won"] = true
			_place_goal(goal, true)
		elif goal["won"] and best < 0.3:
			goal["won"] = false
			_place_goal(goal, false)

# --- Hint spotlight ------------------------------------------------------

## Outline the first ball and pan the camera to it. The outline stays until the
## ball is shoved (see _launch_ball); the camera pans back after hint_camera_hold.
func _start_ball_hint() -> void:
	_hint_ball_node = _balls[0]["node"]
	Outline.add(_hint_ball_node, hint_outline_color, hint_outline_scale, hint_outline_pulse_min, hint_outline_pulse_period)
	if _camera and _camera.has_method("focus_on"):
		_camera.focus_on(_hint_ball_node)
		_hint_cam_timer = hint_camera_hold

func _clear_ball_hint() -> void:
	if _hint_ball_node == null:
		return
	Outline.remove(_hint_ball_node)
	_hint_ball_node = null
	_hint_cam_timer = 0.0
	if _camera and _camera.has_method("release_focus"):
		_camera.release_focus()

# --- Day/night cycle -----------------------------------------------------

## Advance to the next time of day and ease everything toward it.
func _advance_day() -> void:
	if day_phases.is_empty():
		return
	_day_index = (_day_index + 1) % day_phases.size()
	_apply_phase(day_phases[_day_index], true)

## Set (or tween) the sun and environment to a phase's look.
func _apply_phase(phase: DayPhase, animate: bool) -> void:
	var env: Environment = _world_env.environment if _world_env else null
	if _day_tween and _day_tween.is_valid():
		_day_tween.kill()
	if not animate:
		if _sun:
			_sun.rotation_degrees = phase.sun_rotation
			_sun.light_energy = phase.sun_energy
			_sun.light_color = phase.sun_color
		if env:
			env.ambient_light_color = phase.ambient_color
			env.ambient_light_energy = phase.ambient_energy
			env.background_color = phase.sky_color
		return
	# Sunrise-style entry: snap the compass angle now (invisible while dark) so the
	# sun rises in place on this side instead of sweeping the long way around.
	if phase.snap_yaw_on_enter and _sun:
		_sun.rotation_degrees.y = phase.sun_rotation.y
	_day_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t := day_transition_time
	if _sun:
		_day_tween.tween_property(_sun, "rotation_degrees", phase.sun_rotation, t)
		_day_tween.tween_property(_sun, "light_energy", phase.sun_energy, t)
		_day_tween.tween_property(_sun, "light_color", phase.sun_color, t)
	if env:
		_day_tween.tween_property(env, "ambient_light_color", phase.ambient_color, t)
		_day_tween.tween_property(env, "ambient_light_energy", phase.ambient_energy, t)
		_day_tween.tween_property(env, "background_color", phase.sky_color, t)

## Built-in phases used when day_phases is left empty. Afternoon matches the
## scene's default sun; morning mirrors it (sun low from the opposite side).
func _default_day_phases() -> Array[DayPhase]:
	var phases: Array[DayPhase] = []
	# Morning snaps its yaw on entry, so night -> morning rises on the East side
	# instead of the sun swinging all the way around.
	phases.append(_mk_phase("Morning", Vector3(-20, 120, 0), 0.55, Color(1.0, 0.85, 0.7), Color(0.60, 0.64, 0.72), 0.50, Color(0.74, 0.66, 0.60), true))
	phases.append(_mk_phase("Midday", Vector3(-78, -30, 0), 0.65, Color(1.0, 0.98, 0.95), Color(0.75, 0.80, 0.86), 0.60, Color(0.45, 0.64, 0.90)))
	phases.append(_mk_phase("Afternoon", Vector3(-50, -55, 0), 0.85, Color(1.0, 0.95, 0.85), Color(0.70, 0.78, 0.85), 0.55, Color(0.50, 0.66, 0.86)))
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

# --- Rolling balls -------------------------------------------------------

func _spawn_balls() -> void:
	if ball_tiles.is_empty():
		return
	_ball_scene = load("res://models/ball.glb")
	if _ball_scene == null:
		push_warning("World: could not load ball.glb")
		return
	var ab := _measure_aabb_y(_ball_scene)
	_ball_radius = (ab.y - ab.x) * 0.5
	for tile in ball_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		var node := _ball_scene.instantiate() as Node3D
		node.position = _ball_world_pos(tile)
		_grid_root.add_child(node)
		_balls.append({
			"node": node, "dir": Vector2i.ZERO, "speed": 0.0,
			"resting": true, "tile": tile, "start": tile,
		})

func _ball_world_pos(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * cell_size, get_elevation(tile.x, tile.y) + 0.5 + _ball_radius, tile.y * cell_size)

## Any ball (rolling or resting) currently over this tile.
func _ball_at(tile: Vector2i) -> Dictionary:
	for ball in _balls:
		var n: Node3D = ball["node"]
		if Vector2i(roundi(n.position.x / cell_size), roundi(n.position.z / cell_size)) == tile:
			return ball
	return {}

func _player_tile() -> Vector2i:
	if _player == null:
		return Vector2i(-9999, -9999)
	return Vector2i(roundi(_player.global_position.x / cell_size), roundi(_player.global_position.z / cell_size))

func _launch_ball(ball: Dictionary, dir: Vector2i) -> bool:
	var node: Node3D = ball["node"]
	var cur := Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))
	if _ball_blocked(cur + dir, ball):
		return false                       # obstacle right behind it — can't shove

	# Walk the elevation map in `dir`, spending kinetic energy per tile. Uphill
	# tiles cost more, downhill less, so the ball travels a whole number of tiles
	# that depends on the shove and the terrain. Round at the end.
	var ke := 0.5 * ball_launch_speed * ball_launch_speed
	var tile := cur
	var tiles := 0
	while tiles < grid_size * 2:
		var nxt := tile + dir
		if _ball_blocked(nxt, ball):
			break
		# Open water stops the ball: it rolls in and sinks (final tile).
		if _water.has(nxt) and not _blocks.has(nxt):
			tile = nxt
			tiles += 1
			break
		var de := _base_elev(nxt) - _base_elev(tile)
		var cost := ball_friction * cell_size + ball_slope_accel * de
		if cost <= 0.0:
			ke -= cost                     # downhill: gains energy, keeps rolling
			tile = nxt
			tiles += 1
		elif ke >= cost:
			ke -= cost
			tile = nxt
			tiles += 1
		else:
			if ke / cost >= 0.5:           # reaches past the midpoint: round up
				tiles += 1
			break
	if tiles < 1:
		tiles = 1                          # cur+dir is free, so at least one tile

	var dist := float(tiles) * cell_size
	ball["dir"] = dir
	ball["resting"] = false
	ball["target"] = Vector2((cur.x + dir.x * tiles) * cell_size, (cur.y + dir.y * tiles) * cell_size)
	# Deceleration that stops exactly at the target center, starting at launch speed.
	ball["decel"] = (ball_launch_speed * ball_launch_speed) / (2.0 * dist)
	# First shove of the hinted ball clears its spotlight.
	if ball["node"] == _hint_ball_node:
		_clear_ball_hint()
	return true

func _ball_blocked(tile: Vector2i, self_ball: Dictionary) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return true
	if _blocks.has(tile) and not _water.has(tile):
		return true                     # land crate blocks; a floating crate is rollable
	if tile == _player_tile():
		return true                     # don't roll through the cat
	for b in _balls:
		if b != self_ball and b["resting"] and b["tile"] == tile:
			return true
	return false

func _base_elev(tile: Vector2i) -> float:
	if tile.x >= 0 and tile.x < grid_size and tile.y >= 0 and tile.y < grid_size:
		# Roll on top of a floating crate; else the terrain height.
		if _water.has(tile) and _blocks.has(tile):
			return get_elevation(tile.x, tile.y)
		return float(_heights[tile.x][tile.y])
	return 0.0

func _update_balls(delta: float) -> void:
	for ball in _balls:
		if not ball["resting"]:
			_roll_ball(ball, delta)
		_update_ball_height(ball, delta)

func _roll_ball(ball: Dictionary, delta: float) -> void:
	var node: Node3D = ball["node"]
	var d: Vector2i = ball["dir"]
	var target: Vector2 = ball["target"]
	var rem := (target - Vector2(node.position.x, node.position.z)).length()
	if rem <= 0.005:
		node.position.x = target.x
		node.position.z = target.y
		_rest_ball(ball)
		return
	# Constant deceleration toward the precomputed target: v = sqrt(2*a*remaining)
	# gives a smooth slow-down that reaches exactly 0 at the tile centre.
	var v: float = sqrt(2.0 * ball["decel"] * rem)
	var move := minf(v * delta, rem)
	# Stop centred on the last free tile if something (the cat, a crate) is now in
	# the way — so a rolling ball can't pass through the player.
	var cur_tile := Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))
	var next_tile := Vector2i(roundi((node.position.x + d.x * move) / cell_size), roundi((node.position.z + d.y * move) / cell_size))
	if next_tile != cur_tile and _ball_blocked(next_tile, ball):
		node.position.x = cur_tile.x * cell_size
		node.position.z = cur_tile.y * cell_size
		_rest_ball(ball)
		return
	node.position.x += d.x * move
	node.position.z += d.y * move
	_spin(node, d, move)
	if rem - move <= 0.005:
		node.position.x = target.x
		node.position.z = target.y
		_rest_ball(ball)

func _spin(node: Node3D, d: Vector2i, dist: float) -> void:
	var axis := Vector3(d.y, 0.0, -d.x)
	if axis.length() > 0.0:
		node.rotate(axis.normalized(), dist / _ball_radius)

func _rest_ball(ball: Dictionary) -> void:
	ball["resting"] = true
	ball["speed"] = 0.0
	ball["dir"] = Vector2i.ZERO
	var node: Node3D = ball["node"]
	ball["tile"] = Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))

func _update_ball_height(ball: Dictionary, delta: float) -> void:
	var node: Node3D = ball["node"]
	var tx := roundi(node.position.x / cell_size)
	var tz := roundi(node.position.z / cell_size)
	var tile := Vector2i(tx, tz)
	var target_y: float
	var rate := 15.0
	if _water.has(tile) and not _blocks.has(tile):
		# Open water: no float — sink (slowly) to the pond floor.
		target_y = (_water_surface - 1.0) + _ball_radius
		rate = 4.0
	else:
		# Terrain, or the top of a floating crate (get_elevation returns its top).
		target_y = get_elevation(tx, tz) + 0.5 + _ball_radius
	node.position.y = lerpf(node.position.y, target_y, 1.0 - exp(-rate * delta))

## Min and max Y of a single-node glb relative to its origin (bottom & top).
func _measure_aabb_y(scene: PackedScene) -> Vector2:
	var inst := scene.instantiate()
	add_child(inst)
	var min_y := INF
	var max_y := -INF
	for mi in _all_mesh_instances(inst):
		var m := mi as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb()
		min_y = minf(min_y, box.position.y)
		max_y = maxf(max_y, box.position.y + box.size.y)
	inst.queue_free()
	if is_inf(min_y):
		return Vector2(0.0, 0.2)
	return Vector2(min_y - global_position.y, max_y - global_position.y)
