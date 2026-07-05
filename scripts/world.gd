class_name World
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
## Starting sun angle (Euler degrees). Day/night scenes override it per phase; for
## static scenes it sets how high/low and from which side the sun sits.
@export var sun_angle: Vector3 = Vector3(-50.0, -55.0, 0.0)
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
## Sample the map mesh's surface height per tile so the cat walks up/down the
## terrain (instead of a flat custom map). Read from the mesh geometry at load.
@export var follow_map_height: bool = false
## Only tiles that lie over the map mesh are walkable — everything else (open sea,
## off-map) is blocked. Uses the same map-mesh scan as follow_map_height.
@export var confine_to_land: bool = false
## Water line for confine_to_land: land whose surface is above this Y is walkable
## (grass + beach); anything below (the underwater seafloor) is blocked. Lower it if
## the cat can't reach the beach; raise it if the cat walks out onto the sea floor.
@export var sea_level: float = 0.0
## Scatter grass directly on the map's green (grass) surface geometry — density is
## grass_per_area blades per m². Follows the mesh with no per-tile gaps; use this
## for a coloured-material map (scene 5) instead of grass_from_paint's tile grid.
@export var grass_on_map_surface: bool = false
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
## Tile mode density: blades scattered per grass tile (scene 4's painted grass).
@export var grass_per_tile: int = 180
## Area (mesh) mode density: blades per square metre of surface (scenes 1 & 5,
## where grass is scattered over the terrain/map mesh). Separate knob since it's a
## different metric than grass_per_tile — tune each to match visually.
@export var grass_per_area: float = 220.0
## Grass is split into square chunks this many tiles across, each its own
## MultiMesh, so off-screen chunks are frustum-culled (big win on large maps).
@export var grass_chunk_size: int = 16
## How far each blade wanders within its slot on the tile (0 = perfect grid,
## 1 = can reach neighbouring slots). Push toward 1 to break up the grid look.
@export var grass_jitter: float = 1.0
## Overall size multiplier on the model's native size (lower this if the tuft
## imported bigger than you want; 1.0 = original size).
@export var grass_scale: float = 0.8
## Per-blade random yaw. 0 = every blade faces the same way, 1 = full 360° random.
@export_range(0.0, 1.0) var grass_yaw_jitter: float = 1.0
## Per-blade random size, downward only. 0 = every blade full size, 0.5 = blades
## range from half size up to full (never larger than grass_scale).
@export_range(0.0, 0.95) var grass_size_random: float = 0.6
## Grass colour (the tips; roots are a touch darker).
@export var grass_color: Color = Color("6a9b47")
## How much blade normals lean toward straight up (0 = raw mesh, 1 = fully up).
## Higher stops thin blades self-shading to black under an overhead sun.
@export_range(0.0, 1.0) var grass_normal_up: float = 0.65
## Let grass cast shadows. Off avoids the shimmering self-shadow jitter that thin
## swaying blades cause in the directional shadow map (grass still receives them).
@export var grass_cast_shadows: bool = false
## Wind tip-sway distance (m) and speed.
@export var grass_wind_strength: float = 0.1
@export var grass_wind_speed: float = 0.8
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
@export var grass_bend_strength: float = 0.4
## Seconds a flattened blade takes to spring back upright after the cat leaves.
## Each blade fades on its own timer, so higher = a longer-lingering wake.
@export var grass_recovery: float = 5.5
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
## Optional tip shown in the hint banner while the ball is spotlighted (blank =
## none). Cleared when the ball is first shoved.
@export var hint_ball_text: String = ""
## Seconds the camera holds on the cat FIRST, before panning over to the ball.
@export var hint_pre_hold: float = 1.0
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

var _npc: NpcDirector                # runtime controller (see npc_director.gd)
var _interaction: InteractionController   # runtime controller (see interaction.gd)
var _keyhole: KeyholeEffect          # runtime controller (see keyhole_effect.gd)

var _heights: Array = []
var _noise: FastNoiseLite
var _defs: Array = []           # [{scene, mask, top}]
var _box_tile_mesh: BoxMesh     # shared mesh+material for plain_box_tiles
var _land: Dictionary = {}      # tile -> true, tiles that lie over the map mesh (scene 5)
var _land_scanned := false
var _grass_tris: PackedVector3Array = PackedVector3Array()   # green-surface world triangles
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
# Intro camera: 0 = idle, 1 = holding on the cat, 2 = holding on the ball.
var _intro_phase := 0
var _intro_timer := 0.0
# Crate hint (triggered after the first NPC talk): outline a crate, fire
# hint_crate_pushed once it's shoved.
signal hint_crate_pushed
var _hint_crate_node: Node3D = null
var _hint_crate_start := Vector2i.ZERO
var _hint_crate_active := false
# Fires once, the first time any ball is shoved.
signal ball_pushed
var _ball_pushed_emitted := false

# --- Grass ---
# Typed as Node (not GrassField) and loaded at runtime, so World doesn't reference
# the GrassField class at parse time — GrassField references World back, and a
# compile-time cycle would stop GrassField from registering.
var _grass: Node                # runtime controller (see grass_field.gd)
const _GRASS_FIELD_SCRIPT := "res://scripts/grass_field.gd"

@onready var _grid_root: Node3D = $Grid
@onready var _player: CharacterBody3D = $Player
@onready var _sun: DirectionalLight3D = $Sun
@onready var _fill: DirectionalLight3D = get_node_or_null("Fill")
@onready var _camera: Camera3D = get_node_or_null("Camera")
@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")

# --- Day/night ---
var _day_night: DayNightCycle   # runtime controller (see day_night.gd)

var _obstacle: Dictionary = {}   # cached map-feature blocked tiles (lazy)
var _obstacle_built := false

func _ready() -> void:
	if _sun:
		_sun.rotation_degrees = sun_angle
	# Fill light from a different angle (no shadows) so surfaces in the sun's cast
	# shadow still get directional shading instead of flat ambient.
	if _fill:
		_fill.rotation_degrees = Vector3(-55.0, 130.0, 0.0)
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
		_player.npc_provider = Callable(self, "_tile_has_npc")
		_player.view_camera = _camera
		_player.sync_to_grid()
		_player_start = _player.global_position
	_setup_click_catcher()
	if enable_keyhole:
		_keyhole = KeyholeEffect.new()
		_keyhole.name = "KeyholeEffect"
		add_child(_keyhole)
		_keyhole.setup(_camera, _player, _keyhole_roots(),
			keyhole_radius, keyhole_softness, keyhole_min_alpha, keyhole_depth_bias, keyhole_clear_radius)
	if hint_ball_at_start and not _balls.is_empty():
		_start_ball_hint()
	if day_night_enabled and _sun:
		_day_night = DayNightCycle.new()
		_day_night.name = "DayNightCycle"
		add_child(_day_night)
		var env: Environment = _world_env.environment if _world_env else null
		_day_night.setup(_sun, env, day_transition_time, day_phases)
	if npc_enabled:
		_npc = NpcDirector.new()
		_npc.name = "NpcDirector"
		add_child(_npc)
		_npc.setup(self, grid_size, cell_size, ground_y, npc_walk_speed)
	# Interaction: added last so its _unhandled_input runs before the camera's,
	# letting it consume the Interact key (talking never doubles as a camera move).
	if _player:
		_interaction = InteractionController.new()
		_interaction.name = "InteractionController"
		add_child(_interaction)
		_interaction.setup(self, _player, cell_size)

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

	# Custom map (scene 5): read walkable extent + per-tile height + grass triangles.
	if not generate_terrain and (confine_to_land or follow_map_height or grass_on_map_surface):
		_scan_map_surface()

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
	# When grass covers the whole terrain, collect the top triangles so grass can be
	# scattered evenly over the surface (mesh mode) instead of per-tile.
	var want_grass := grass_on_all_tiles
	for x in grid_size:
		for z in grid_size:
			if not _is_ground(x, z):
				continue
			# Smooth top quad (corners shared with neighbours -> continuous surface).
			_tri(top, x, z, x, z + 1, x + 1, z + 1)
			_tri(top, x, z, x + 1, z + 1, x + 1, z)
			if want_grass:
				_grass_tris.append(_corner_pos(x, z)); _grass_tris.append(_corner_pos(x, z + 1)); _grass_tris.append(_corner_pos(x + 1, z + 1))
				_grass_tris.append(_corner_pos(x, z)); _grass_tris.append(_corner_pos(x + 1, z + 1)); _grass_tris.append(_corner_pos(x + 1, z))
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

## Scan the map (land) mesh once, rasterising every surface's triangles into the
## tiles they cover. Sets each tile's height (`_heights`) from the topmost covering
## surface (so movement follows the terrain), marks tiles above `sea_level` walkable
## (`_land`, only used when confine_to_land is on), and collects the greenest
## ("grass") surface's world triangles (`_grass_tris`) for mesh-scattered grass.
func _scan_map_surface() -> void:
	if _land_scanned:
		return
	var map := get_node_or_null(map_path)
	if map == null:
		push_warning("World: confine_to_land / follow_map_height need a map_path.")
		return
	var mi: MeshInstance3D = null
	for m in _all_mesh_instances(map):
		mi = m
		break
	if mi == null or mi.mesh == null:
		return
	_land_scanned = true
	var xf: Transform3D = mi.global_transform
	# The greenest-material surface is the grass (only it grows grass blades).
	var grass_surf := -1
	var greenest := -1000.0
	for s in mi.mesh.get_surface_count():
		var sm: Material = mi.get_active_material(s)
		if sm is BaseMaterial3D:
			var col: Color = (sm as BaseMaterial3D).albedo_color
			var g := col.g - maxf(col.r, col.b)
			if g > greenest:
				greenest = g
				grass_surf = s
	var got: Dictionary = {}                # tiles whose height has been set (take the top)
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var wv := PackedVector3Array()
		wv.resize(verts.size())
		for i in verts.size():
			wv[i] = xf * verts[i]
		var is_grass := grass_on_map_surface and s == grass_surf
		var tri_n: int = (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
		for ti in tri_n:
			var i0: int
			var i1: int
			var i2: int
			if idx.size() > 0:
				i0 = idx[ti * 3]; i1 = idx[ti * 3 + 1]; i2 = idx[ti * 3 + 2]
			else:
				i0 = ti * 3; i1 = ti * 3 + 1; i2 = ti * 3 + 2
			var a := wv[i0]
			var b := wv[i1]
			var c := wv[i2]
			# Grass is scattered directly on the green surface's triangles (mesh mode).
			if is_grass:
				_grass_tris.append(a); _grass_tris.append(b); _grass_tris.append(c)
			var tx0 := maxi(int(ceil(minf(a.x, minf(b.x, c.x)) / cell_size)), 0)
			var tx1 := mini(int(floor(maxf(a.x, maxf(b.x, c.x)) / cell_size)), grid_size - 1)
			var tz0 := maxi(int(ceil(minf(a.z, minf(b.z, c.z)) / cell_size)), 0)
			var tz1 := mini(int(floor(maxf(a.z, maxf(b.z, c.z)) / cell_size)), grid_size - 1)
			var e0 := Vector2(b.x - a.x, b.z - a.z)
			var e1 := Vector2(c.x - a.x, c.z - a.z)
			var d00 := e0.dot(e0)
			var d01 := e0.dot(e1)
			var d11 := e1.dot(e1)
			var denom := d00 * d11 - d01 * d01
			if absf(denom) < 0.0000001:
				continue
			for tx in range(tx0, tx1 + 1):
				for tz in range(tz0, tz1 + 1):
					var e2 := Vector2(tx * cell_size - a.x, tz * cell_size - a.z)
					var d20 := e2.dot(e0)
					var d21 := e2.dot(e1)
					var vv := (d11 * d20 - d01 * d21) / denom
					var ww := (d00 * d21 - d01 * d20) / denom
					var uu := 1.0 - vv - ww
					if uu < -0.01 or vv < -0.01 or ww < -0.01:
						continue                # tile centre isn't inside this triangle
					var y := uu * a.y + vv * b.y + ww * c.y
					var t := Vector2i(tx, tz)
					# Height everywhere there's land mesh, so movement follows the
					# terrain even into the shallows; walkability (confine, if used)
					# still respects the water line.
					if follow_map_height:
						var elev := y - 0.5
						if not got.has(t):
							_heights[tx][tz] = elev
							got[t] = true
						elif elev > float(_heights[tx][tz]):
							_heights[tx][tz] = elev   # keep the topmost surface
					if y >= sea_level:
						_land[t] = true

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
## Pick the grass tiles (from paint, all-ground, or the explicit list) and hand
## them to a GrassField node, which owns the blades and the footprint interaction.
func _spawn_grass() -> void:
	# Mesh mode: scatter grass evenly over collected surface triangles — scene 5's
	# green map surface (from the map scan) or scene 1's smooth terrain top.
	if not _grass_tris.is_empty():
		_grass = load(_GRASS_FIELD_SCRIPT).new()
		_grass.name = "GrassField"
		add_child(_grass)
		_grass.setup_mesh(self, _player, _grid_root, _grass_tris, grass_per_area, _goal_tiles())
		return
	# Tile mode (scene 4 paint / explicit tile lists): grass on grid tiles.
	var tiles: Array[Vector2i]
	if grass_on_all_tiles:
		tiles = _grass_all_ground_tiles()
	elif grass_from_paint:
		tiles = _grass_tiles_from_paint()
	else:
		tiles = grass_tiles
	if tiles.is_empty():
		return
	_grass = load(_GRASS_FIELD_SCRIPT).new()
	_grass.name = "GrassField"
	add_child(_grass)
	_grass.setup(self, _player, _grid_root, tiles, _goal_tiles())

## The tiles occupied by goal pads (so grass can skip them).
func _goal_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for g in _goals:
		out.append(g["tile"])
	return out

## The tile of the ball-triggered goal, or (-1, -1) if there isn't one.
func ball_goal_tile() -> Vector2i:
	for g in _goals:
		if g["by"] == "ball":
			return g["tile"]
	return Vector2i(-1, -1)

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
## flat top (`fallback`) is used. Called by GrassField when scattering blades.
func grass_surface_y(wx: float, wz: float, fallback: float) -> float:
	if not smooth_terrain:
		return fallback
	var tx := roundi(wx / cell_size)
	var tz := roundi(wz / cell_size)
	var u := clampf(wx / cell_size - float(tx) + 0.5, 0.0, 1.0)
	var v := clampf(wz / cell_size - float(tz) + 0.5, 0.0, 1.0)
	var a := lerpf(_corner_y(tx, tz), _corner_y(tx + 1, tz), u)
	var b := lerpf(_corner_y(tx, tz + 1), _corner_y(tx + 1, tz + 1), u)
	return lerpf(a, b, v)

## Moving objects that also flatten grass (besides the cat): pushed crates and
## rolling balls. Returns {pos, radius} per object; GrassField presses under each.
func grass_pressers() -> Array:
	var out: Array = []
	var crate_r := cell_size * 0.9   # a crate flattens its whole tile (and a touch over)
	for tile in _blocks:
		var b: Node3D = _blocks[tile]
		out.append({"pos": b.global_position, "radius": crate_r})
	var ball_r := _ball_radius + 0.25
	for ball in _balls:
		var n: Node3D = ball["node"]
		out.append({"pos": n.global_position, "radius": ball_r})
	return out

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
	if Dialogue.is_active():
		return                               # frozen during a conversation
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

## Public: is a crate or ball on this tile? (For the NPC to route around them.)
func has_pushable(tile: Vector2i) -> bool:
	return _is_pushable_tile(tile)

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

## Public walkability test (for scripted movers like the villager guide).
func path_walkable(tile: Vector2i) -> bool:
	_ensure_obstacles()
	return _path_walkable(tile)

## Shortest walkable path that also MINIMISES the number of turns (so scripted
## walks look direct, not staircase-y). Dijkstra over (tile, entry-direction)
## states with cost = turns*1000 + steps. Returns tiles from the first step to
## `goal`, or [] if unreachable. Grid is small, so the simple frontier is fine.
func find_path_min_turns(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	_ensure_obstacles()
	if not _path_walkable(goal):
		return []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	const NONE := 4
	const INF := 1 << 30
	var start_state := Vector3i(start.x, start.y, NONE)
	var best := {start_state: 0}
	var came := {}
	var frontier: Array = [[0, start_state]]
	var goal_state = null
	while not frontier.is_empty():
		var mi := 0
		for i in range(1, frontier.size()):
			if frontier[i][0] < frontier[mi][0]:
				mi = i
		var top: Array = frontier[mi]
		frontier.remove_at(mi)
		var cost: int = top[0]
		var state: Vector3i = top[1]
		if cost > int(best.get(state, INF)):
			continue
		var tile := Vector2i(state.x, state.y)
		if tile == goal:
			goal_state = state
			break
		for di in 4:
			var n: Vector2i = tile + dirs[di]
			if not _path_walkable(n):
				continue
			var turn := 1 if (state.z != NONE and di != state.z) else 0
			var nc: int = cost + turn * 1000 + 1
			var ns := Vector3i(n.x, n.y, di)
			if nc < int(best.get(ns, INF)):
				best[ns] = nc
				came[ns] = state
				frontier.append([nc, ns])
	if goal_state == null:
		return []
	var path: Array = []
	var s: Vector3i = goal_state
	while s != start_state:
		path.push_front(Vector2i(s.x, s.y))
		s = came[s]
	return path

func _path_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return false
	if confine_to_land and not _land.has(tile):
		return false
	if _tile_has_npc(tile):
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
			var t := Vector2i(x, z)
			if confine_to_land and not _land.has(t):
				continue                       # no walls out on the sea — skip it
			if _player.is_tile_blocked(t):
				_obstacle[t] = true

# --- Background NPC (obstacle map is shared; the NpcDirector node does the rest) --

## Build (if needed) the static-obstacle map and report whether it's ready. The
## NpcDirector waits on this before spawning.
func ensure_obstacle_map() -> bool:
	_ensure_obstacles()
	return _obstacle_built

## Is this tile blocked by static geometry (building/wall/map feature)?
func is_map_obstacle(tile: Vector2i) -> bool:
	return _obstacle.has(tile)

## Is an NPC standing on this tile? Covers the roaming background NPC and any
## stationary talkable (an Interactable in the "interactable" group). Used to keep
## the player from sharing a tile with them.
func _tile_has_npc(tile: Vector2i) -> bool:
	if _npc and _npc.npc_tile() == tile:
		return true
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and node.interact_tile(cell_size) == tile:
			return true
	return false

## Called by the player: can it step onto `tile` moving in `dir`?
## Returns true (free), false (blocked), or {block, from, to} when a block is
## being pushed — the player then slides that block in lockstep with itself.
func can_enter(tile: Vector2i, dir: Vector2i) -> Variant:
	# Off the land (open sea / off-map) is never walkable.
	if confine_to_land and not _land.has(tile):
		return false
	# An NPC (roaming or a stationary talkable) occupies its tile — can't share it.
	if _tile_has_npc(tile):
		return false
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
	if _holes.has(beyond) or not _ball_at(beyond).is_empty() or _tile_has_npc(beyond):
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
	if _holes.has(dest) or _blocks.has(dest) or not _ball_at(dest).is_empty() or _tile_has_npc(dest):
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
	_update_intro_camera(delta)
	_update_crate_hint()

# --- Keyhole see-through --------------------------------------------------

## The building root node(s) the keyhole effect should target. If buildings_path
## is set we use ONLY that node (map/floor stays solid); otherwise we fall back to
## the rest of the scene (minus terrain & the cat).
func _keyhole_roots() -> Array:
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
	return roots

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
	# Start held on the cat; _update_intro_camera pans to the ball after hint_pre_hold,
	# and only then shows the hint (so it doesn't appear before the camera gets there).
	_intro_phase = 1
	_intro_timer = hint_pre_hold

## Drive the intro camera: hold on the cat, pan to the ball, then back.
func _update_intro_camera(delta: float) -> void:
	if _intro_phase == 0:
		return
	_intro_timer -= delta
	if _intro_timer > 0.0:
		return
	if _intro_phase == 1:
		_intro_phase = 2
		_intro_timer = hint_camera_hold
		if _hint_ball_node and _camera and _camera.has_method("focus_on"):
			_camera.focus_on(_hint_ball_node)
		Dialogue.show_hint(hint_ball_text)
	else:
		_intro_phase = 0
		if _camera and _camera.has_method("release_focus"):
			_camera.release_focus()

func _clear_ball_hint() -> void:
	if _hint_ball_node == null:
		return
	Outline.remove(_hint_ball_node)
	_hint_ball_node = null
	_intro_phase = 0
	if _camera and _camera.has_method("release_focus"):
		_camera.release_focus()
	Dialogue.hide_hint()

## Outline one crate the same way the ball is spotlighted. When that crate is
## later shoved, `hint_crate_pushed` fires once (see _update_crate_hint). Called by
## the villager guide after the first conversation.
func highlight_hint_crate() -> void:
	if _hint_crate_active:
		return
	var tile: Vector2i
	if not block_tiles.is_empty() and _blocks.has(block_tiles[0]):
		tile = block_tiles[0]
	elif not _blocks.is_empty():
		tile = _blocks.keys()[0]
	else:
		return
	_hint_crate_node = _blocks[tile]
	_hint_crate_start = tile
	_hint_crate_active = true
	Outline.add(_hint_crate_node, hint_outline_color, hint_outline_scale, hint_outline_pulse_min, hint_outline_pulse_period)

## Watch the hinted crate; once it leaves its start tile, clear the outline and
## emit hint_crate_pushed (once).
func _update_crate_hint() -> void:
	if not _hint_crate_active or _hint_crate_node == null:
		return
	var t := Vector2i(roundi(_hint_crate_node.position.x / cell_size), roundi(_hint_crate_node.position.z / cell_size))
	if t != _hint_crate_start:
		_hint_crate_active = false
		Outline.remove(_hint_crate_node)
		_hint_crate_node = null
		hint_crate_pushed.emit()

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
	if not _ball_pushed_emitted:
		_ball_pushed_emitted = true
		ball_pushed.emit()
	return true

func _ball_blocked(tile: Vector2i, self_ball: Dictionary) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return true
	if _blocks.has(tile) and not _water.has(tile):
		return true                     # land crate blocks; a floating crate is rollable
	if tile == _player_tile():
		return true                     # don't roll through the cat
	if _tile_has_npc(tile):
		return true                     # don't roll through the NPC
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
