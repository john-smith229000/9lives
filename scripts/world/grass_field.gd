extends Node
class_name GrassField
## Scatters grass blades (blade1.glb..blade5.glb) as wind-shaded MultiMeshes over a
## set of tiles, and runs the per-blade footprint interaction as the cat walks and
## lands. Created at runtime by World, which passes the tile list; all tuning is
## read from the World's grass_* exports so the scenes configure it as before.

var _world: World
var _player: Node3D
var _grid_root: Node3D          # the MultiMeshes live here (under World's "Grid")
var _mats: Array[ShaderMaterial] = []
var _mms: Array = []                    # the MultiMeshes (for writing per-blade custom data)
# Per-blade bookkeeping (indexed by a global blade id).
var _blade_mm: PackedInt32Array = PackedInt32Array()   # which MultiMesh
var _blade_idx: PackedInt32Array = PackedInt32Array()  # instance index inside it
var _blade_pos: PackedVector3Array = PackedVector3Array()
var _bins: Dictionary = {}              # tile -> Array of blade ids near it
var _active: Dictionary = {}            # blade id -> Vector3(bend, dir.x, dir.z) still recovering
var _exclude: Dictionary = {}           # tiles that get no grass (e.g. goal pads)
const CLIP_MAX := 8                     # must match grass_wind.gdshader's CLIP_MAX
var _clip_n := 0                        # occluders uploaded last frame (so we can zero once)
# Height zones: blade variants are grouped into height tiers (short/regular/tall)
# and each blade picks a tier from the World's height map so areas read as mown,
# normal or overgrown, with smooth transitions between them. _present_tiers lists
# the tiers that actually have meshes, in increasing-height order; _tier_meshes
# maps a tier id to the indices (into the flat mesh list) of that tier's blades.
const TIER_SHORT := 0
const TIER_REGULAR := 1
const TIER_TALL := 2
var _present_tiers: Array = []
var _tier_meshes: Dictionary = {}

## Tile mode (scenes 1–4): one blade per sub-grid cell of each grass tile.
func setup(world: World, player: Node3D, grid_root: Node3D, tiles: Array[Vector2i], exclude: Array[Vector2i] = []) -> void:
	_world = world
	_player = player
	_grid_root = grid_root
	_set_exclude(exclude)
	var meshes := _build_blade_tiers()
	if meshes.is_empty():
		push_warning("GrassField: no blade meshes (models/grass/blade1.glb ...) found — no grass.")
		return
	_build(meshes, _scatter_tiles(meshes, tiles))

func _set_exclude(tiles: Array[Vector2i]) -> void:
	_exclude.clear()
	for t in tiles:
		_exclude[t] = true

## Mesh mode (scene 5): scatter blades directly over world-space triangles (`tris`,
## groups of 3) at `density` blades per m², so grass follows the surface exactly
## with no per-tile gaps. Movement + bending stay tile-based (bins below).
func setup_mesh(world: World, player: Node3D, grid_root: Node3D, tris: PackedVector3Array, density: float, exclude: Array[Vector2i] = []) -> void:
	_world = world
	_player = player
	_grid_root = grid_root
	_set_exclude(exclude)
	var meshes := _build_blade_tiers()
	if meshes.is_empty():
		push_warning("GrassField: no blade meshes (models/grass/blade1.glb ...) found — no grass.")
		return
	_build(meshes, _scatter_mesh(meshes, tris, density))

## Per-blade rotation + size: random yaw (scaled by grass_yaw_jitter) and a uniform
## random size that only ever shrinks the blade (never larger than grass_scale).
func _blade_xform(rng: RandomNumberGenerator) -> Transform3D:
	var yaw := rng.randf() * TAU * _world.grass_yaw_jitter
	var lo := maxf(1.0 - _world.grass_size_random, 0.05)
	var s := _world.grass_scale * rng.randf_range(lo, 1.0)
	return Transform3D.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3(s, s, s))

## Fill one transform list per blade variant by scattering over the grass tiles
## (with jitter), each blade on the tile's interpolated surface height.
func _scatter_tiles(meshes: Array, tiles: Array[Vector2i]) -> Array:
	var cell := _world.cell_size
	var rng := RandomNumberGenerator.new()
	var per := _world.grass_per_tile
	if RetroMode.active:
		per = maxi(1, int(round(per * RetroMode.GRASS_DENSITY)))
	var lists: Array = []
	for _m in meshes:
		lists.append([])
	for tile in tiles:
		if tile.x < 0 or tile.x >= _world.grid_size or tile.y < 0 or tile.y >= _world.grid_size:
			continue
		if _exclude.has(tile):
			continue
		var top := _world.get_elevation(tile.x, tile.y) + 0.5
		var cols := maxi(int(ceil(sqrt(float(per)))), 1)
		var sub := cell / float(cols)
		var origin_x := tile.x * cell - cell * 0.5
		var origin_z := tile.y * cell - cell * 0.5
		for i in per:
			var cx := origin_x + (float(i % cols) + 0.5) * sub
			var cz := origin_z + (float(i / cols) + 0.5) * sub
			var t := _blade_xform(rng)
			var wx := cx + rng.randf_range(-0.5, 0.5) * sub * _world.grass_jitter
			var wz := cz + rng.randf_range(-0.5, 0.5) * sub * _world.grass_jitter
			t.origin = Vector3(wx, _world.grass_surface_y(wx, wz, top), wz)
			if _keep_blade(wx, wz, rng):
				(lists[_pick_blade(wx, wz, rng)] as Array).append(t)
	return lists

## Fill one transform list per blade variant by scattering uniformly over the mesh
## triangles at `density` blades per m² (blades sit exactly on the surface).
func _scatter_mesh(meshes: Array, tris: PackedVector3Array, density: float) -> Array:
	var rng := RandomNumberGenerator.new()
	var lists: Array = []
	for _m in meshes:
		lists.append([])
	var dens := density * (RetroMode.GRASS_DENSITY if RetroMode.active else 1.0)
	var n_tri := tris.size() / 3
	for ti in n_tri:
		var a := tris[ti * 3]
		var b := tris[ti * 3 + 1]
		var c := tris[ti * 3 + 2]
		var n := int(round(0.5 * (b - a).cross(c - a).length() * dens))
		for _k in n:
			var r1 := rng.randf()
			var r2 := rng.randf()
			if r1 + r2 > 1.0:
				r1 = 1.0 - r1
				r2 = 1.0 - r2
			var t := _blade_xform(rng)
			t.origin = a + (b - a) * r1 + (c - a) * r2
			if not _exclude.is_empty():
				var bt := Vector2i(roundi(t.origin.x / _world.cell_size), roundi(t.origin.z / _world.cell_size))
				if _exclude.has(bt):
					continue
			if _keep_blade(t.origin.x, t.origin.z, rng):
				(lists[_pick_blade(t.origin.x, t.origin.z, rng)] as Array).append(t)
	return lists

## Turn per-variant transform lists into MultiMeshInstances + the footprint bins.
## Blades are bucketed into square chunks (grass_chunk_size tiles) per variant, so
## each MultiMesh spans only its chunk and off-screen chunks get frustum-culled.
func _build(meshes: Array, lists: Array) -> void:
	var cell := _world.cell_size
	var chunk := maxf(float(_world.grass_chunk_size) * cell, cell)
	# One shared material per blade variant (reused across all of that variant's chunks).
	for k in meshes.size():
		_mats.append(_material(maxf((meshes[k] as Mesh).get_aabb().size.y, 0.01)))
	# Bucket every transform by (chunk x, chunk z, blade variant).
	var buckets: Dictionary = {}
	for k in meshes.size():
		for xf in (lists[k] as Array):
			var pos: Vector3 = (xf as Transform3D).origin
			var key := Vector3i(floori(pos.x / chunk), floori(pos.z / chunk), k)
			var b: Array = buckets.get(key, [])
			b.append(xf)
			buckets[key] = b
	for key in buckets:
		var k: int = key.z
		var xforms: Array = buckets[key]
		var mesh: Mesh = meshes[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true     # per-blade bend amount + push direction
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		var mm_index := _mms.size()
		for i in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))   # start un-bent
			var gid := _blade_mm.size()
			_blade_mm.append(mm_index)
			_blade_idx.append(i)
			_blade_pos.append(xf.origin)
			var btile := Vector2i(roundi(xf.origin.x / cell), roundi(xf.origin.z / cell))
			var bin: Array = _bins.get(btile, [])
			bin.append(gid)
			_bins[btile] = bin
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# Thin, swaying blades make the directional shadow map shimmer; off by
		# default kills that jitter (grass still receives shadows from buildings).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _world.grass_cast_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.material_override = _mats[k]   # shared per-variant material
		_mms.append(mm)
		_grid_root.add_child(mmi)

## Load every blade variant into height tiers and return them as one flat list (the
## order _build/_material expect). Regular blades are models/grass/blade1..5.glb; the
## shorter set is blade_s1..5.glb and the taller set blade_t1..6.glb. Height zones
## are only assembled when the World turns them on AND the extra sets exist —
## otherwise just the regular blades load, so every other scene behaves as before.
## _present_tiers / _tier_meshes are filled here for _pick_blade to draw from.
func _build_blade_tiers() -> Array:
	_present_tiers = []
	_tier_meshes = {}
	var flat: Array = []
	var zones: bool = _world.grass_height_zones if "grass_height_zones" in _world else false
	# Optional cap on shapes per tier: fewer MultiMeshes -> fewer draw calls on huge
	# fields, without changing blade count (density). 0 = load the whole set.
	var per_tier: int = _world.grass_blades_per_tier if "grass_blades_per_tier" in _world else 0
	# (tier id, filename prefix, first index, last index), shortest tier first.
	var sets := [
		[TIER_SHORT, "blade_s", 1, 5],
		[TIER_REGULAR, "blade", 1, 5],
		[TIER_TALL, "blade_t", 1, 6],
	]
	for s in sets:
		var tier_id: int = s[0]
		if not zones and tier_id != TIER_REGULAR:
			continue                            # zones off: regular blades only
		var idxs := PackedInt32Array()
		for i in range(int(s[2]), int(s[3]) + 1):
			if per_tier > 0 and idxs.size() >= per_tier:
				break                           # enough shapes for this tier
			var mesh := _load_blade_mesh("res://models/grass/%s%d.glb" % [s[1], i])
			if mesh:
				idxs.append(flat.size())
				flat.append(mesh)
		if not idxs.is_empty():
			_present_tiers.append(tier_id)
			_tier_meshes[tier_id] = idxs
	return flat

## Load one blade .glb and bake its node transform (Blender rotation/scale) into the
## geometry — so the raw MultiMesh mesh is upright and correctly sized even if
## transforms weren't applied on export (otherwise a rotated/oversized node makes
## the blades huge and sideways). Returns null if the file is missing or has no mesh.
func _load_blade_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	add_child(inst)                            # so global_transform resolves
	var mesh: Mesh = null
	for m in _mesh_instances(inst):
		var mi := m as MeshInstance3D
		if mi.mesh:
			mesh = _bake_mesh(mi.mesh, mi.global_transform)
			break
	remove_child(inst)
	inst.queue_free()
	return mesh

## Pick which blade mesh (index into the flat list) grows at world XZ. The World's
## height map gives a value 0..1 (short..tall); we map it onto the tiers that exist
## and, right at a tier boundary, choose between the two neighbouring tiers at random
## in proportion to how far across the boundary we are. A smooth height gradient in
## the map therefore becomes a smoothly shifting mix of short/regular/tall blades —
## the gradation — rather than a hard line. With one tier (zones off) it's uniform.
func _pick_blade(wx: float, wz: float, rng: RandomNumberGenerator) -> int:
	var n := _present_tiers.size()
	if n <= 1:
		var only: PackedInt32Array = _tier_meshes[_present_tiers[0]]
		return only[rng.randi() % only.size()]
	var h := 0.5
	if _world.has_method("grass_height_at"):
		h = clampf(_world.grass_height_at(wx, wz), 0.0, 1.0)
	var p := h * float(n - 1)                  # position along the present tiers
	var lo := int(floor(p))
	var hi := mini(lo + 1, n - 1)
	var frac := p - float(lo)
	var tier_id: int = _present_tiers[hi] if rng.randf() < frac else _present_tiers[lo]
	var pool: PackedInt32Array = _tier_meshes[tier_id]
	return pool[rng.randi() % pool.size()]

## Keep-or-drop test for spatial density variation. The World returns a keep fraction
## (1.0 when the feature is off) that's higher in short grass, lower in tall grass, with
## noise variation; we keep each candidate blade with that probability. Dropping blades
## here — rather than scaling per-tile counts — thins the field smoothly AND lowers the
## blade count wherever it thins, so it doubles as a performance win.
func _keep_blade(wx: float, wz: float, rng: RandomNumberGenerator) -> bool:
	if _world == null or not _world.has_method("grass_density_at"):
		return true
	return rng.randf() < _world.grass_density_at(wx, wz)

## Return a new ArrayMesh with `xf` baked into surface 0's positions and normals.
func _bake_mesh(mesh: Mesh, xf: Transform3D) -> ArrayMesh:
	var src: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var out_v := PackedVector3Array()
	out_v.resize(verts.size())
	for i in verts.size():
		out_v[i] = xf * verts[i]
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = out_v
	if src[Mesh.ARRAY_NORMAL] != null:
		var nrm: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var out_n := PackedVector3Array()
		out_n.resize(nrm.size())
		for i in nrm.size():
			out_n[i] = (xf.basis * nrm[i]).normalized()
		arrs[Mesh.ARRAY_NORMAL] = out_n
	if src[Mesh.ARRAY_INDEX] != null:
		arrs[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am

func _material(blade_h: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/grass_wind.gdshader")
	m.set_shader_parameter("blade_height", blade_h)
	m.set_shader_parameter("tip_color", _world.grass_color)
	m.set_shader_parameter("base_color", _world.grass_color.darkened(0.18))
	m.set_shader_parameter("normal_up", _world.grass_normal_up)
	var sway_mul := RetroMode.GRASS_SWAY if RetroMode.active else 1.0
	m.set_shader_parameter("wind_strength", _world.grass_wind_strength * sway_mul)
	m.set_shader_parameter("wind_speed", _world.grass_wind_speed)
	m.set_shader_parameter("sway_scale", _world.grass_sway_scale * sway_mul)
	m.set_shader_parameter("hue_variation", _world.grass_hue_variation)
	m.set_shader_parameter("brightness_variation", _world.grass_brightness_variation)
	m.set_shader_parameter("patch_variation", _world.grass_patch_variation)
	# Sun-kissed tips: lighter + warmer (more red/green, less blue) than the tips.
	var kiss := _world.grass_color.lightened(0.3)
	kiss.r = minf(1.0, kiss.r + 0.10)
	kiss.g = minf(1.0, kiss.g + 0.06)
	kiss.b = maxf(0.0, kiss.b - 0.04)
	m.set_shader_parameter("tip_highlight", kiss)
	m.set_shader_parameter("tip_kiss", _world.grass_tip_kiss)
	m.set_shader_parameter("shadow_lift", _world.grass_shadow_lift)
	m.set_shader_parameter("bend_strength", _world.grass_bend_strength)
	# The shared cloud-shadow drift (no-op when cloud shadows are disabled).
	if _world.has_method("apply_cloud_params"):
		_world.apply_cloud_params(m)
	return m

func _process(delta: float) -> void:
	_update_clip()   # push crate/ball clip volumes to the grass material (they move)
	if not _active.is_empty() or (not _bins.is_empty() and _player):
		_update(delta)

## Upload the crate/ball clip volumes to the shared grass materials so the shader can
## discard grass fragments inside them (see grass_wind.gdshader). Cheap: a handful of
## uniforms across the per-variant materials, and only while objects exist.
func _update_clip() -> void:
	if _mats.is_empty() or not _world.has_method("grass_occluders"):
		return
	var occ: Array = _world.grass_occluders()
	var n: int = mini(occ.size(), CLIP_MAX)
	if n == 0 and _clip_n == 0:
		return                              # nothing to clip and nothing to clear
	var centers: Array = []
	var exts: Array = []
	centers.resize(CLIP_MAX)
	exts.resize(CLIP_MAX)
	for i in CLIP_MAX:
		if i < n:
			var o: Dictionary = occ[i]
			var c: Vector3 = o["center"]
			if o.get("box", false):
				var h: Vector3 = o["half"]
				centers[i] = Vector4(c.x, c.y, c.z, 0.0)
				exts[i] = Vector4(h.x, h.y, h.z, 0.0)
			else:
				centers[i] = Vector4(c.x, c.y, c.z, 1.0)
				exts[i] = Vector4(float(o["radius"]), 0.0, 0.0, 0.0)
		else:
			centers[i] = Vector4.ZERO
			exts[i] = Vector4.ZERO
	for m in _mats:
		m.set_shader_parameter("clip_count", n)
		m.set_shader_parameter("clip_center", centers)
		m.set_shader_parameter("clip_ext", exts)
	_clip_n = n

## Per-blade grass wake: fade any flattened blades on their own timer, then press
## the grass on the tile under the cat. Only stepped tiles flatten and each recovers
## independently — a settling trail of footprints, no radius/sphere, no wave. Skips
## while airborne so a jump only flattens its takeoff and landing tiles.
func _update(delta: float) -> void:
	var press := delta / maxf(_world.grass_press_time, 0.01)
	# Press FIRST and record every blade a presser is on this frame. Those blades
	# hold their bend; only blades nobody is standing on recover afterwards — so the
	# grass under the cat (or a crate) never springs back up while it sits there.
	var held: Dictionary = {}
	if _player and not (_player.has_method("is_airborne") and _player.is_airborne()):
		# Cat: soft (linear) footprint, over every tile it reaches.
		_press_area(_player.global_position, maxf(_world.grass_footprint, 0.05), press, 0.0, held)
	# Pushed crates and rolling balls flatten grass under them too — a solid, fully
	# flat patch (plateau falloff) over a wider area, so they bend more than the cat.
	for a in _world.grass_pressers():
		_press_area(a["pos"], a["radius"], press, 0.6, held)
	# Recover every OTHER flattened blade on its own timer.
	var fade := delta / maxf(_world.grass_recovery, 0.05)
	var dead: Array = []
	for gid in _active:
		if held.has(gid):
			continue                        # a presser is on it — hold, don't recover
		var e: Vector3 = _active[gid]
		e.x -= fade
		if e.x <= 0.0:
			dead.append(gid)
			_write(gid, 0.0, Vector2.ZERO)
		else:
			_active[gid] = e
			_write(gid, e.x, Vector2(e.y, e.z))
	for gid in dead:
		_active.erase(gid)

## Press the blades on a single tile toward flat, splayed away from `pos`. `inner`
## is the fraction of `radius` that stays fully flat (1.0) before the edge tapers:
## 0.0 = a soft linear footprint (the cat), higher = a solid flattened patch.
func _press_tile(tile: Vector2i, pos: Vector3, radius: float, step: float, inner: float, held: Dictionary) -> void:
	var r := maxf(radius, 0.05)
	var edge := maxf(r * (1.0 - inner), 0.0001)   # width of the tapering rim
	var bin: Array = _bins.get(tile, [])
	for gid in bin:
		var bp: Vector3 = _blade_pos[gid]
		var off := Vector2(bp.x - pos.x, bp.z - pos.z)
		var d := off.length()
		var target := clampf((r - d) / edge, 0.0, 1.0)
		if target <= 0.0:
			continue
		# A presser is on this blade — mark it held so it won't recover this frame,
		# even if it's already flatter than our target (e.g. pressed harder while we
		# walked in). That's what keeps grass down under a standing cat.
		held[gid] = true
		var e: Vector3 = _active[gid] if _active.has(gid) else Vector3.ZERO
		var cur := e.x
		# Already flatter than we'd bend it? Hold it as-is: keep its lean, don't snap
		# it around and don't spring it up toward our shallower target.
		if cur >= target:
			continue
		var dir := off.normalized() if d > 0.0001 else Vector2(0, 1)
		var amt := minf(cur + step, target)
		# Ease the lean toward the new direction instead of snapping it.
		var cur_dir := Vector2(e.y, e.z)
		var new_dir := dir if cur_dir.length() < 0.001 else cur_dir.lerp(dir, 0.25).normalized()
		_active[gid] = Vector3(amt, new_dir.x, new_dir.y)
		_write(gid, amt, new_dir)

## Press all tiles a `radius` reaches, so a footprint bigger than one tile holds
## every blade under it (not just the centre tile) — otherwise the ring that spills
## into neighbouring tiles springs back up while the presser sits still.
func _press_area(pos: Vector3, radius: float, step: float, inner: float, held: Dictionary) -> void:
	var cell: float = _world.cell_size
	var reach := maxi(int(ceil(radius / cell)), 0)
	var ctile := Vector2i(roundi(pos.x / cell), roundi(pos.z / cell))
	for tx in range(ctile.x - reach, ctile.x + reach + 1):
		for tz in range(ctile.y - reach, ctile.y + reach + 1):
			_press_tile(Vector2i(tx, tz), pos, radius, step, inner, held)

## Write one blade's bend amount + push direction into its MultiMesh custom data.
func _write(gid: int, bend: float, dir: Vector2) -> void:
	var mm: MultiMesh = _mms[_blade_mm[gid]]
	mm.set_instance_custom_data(_blade_idx[gid],
		Color(bend, dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, 0.0))

## Every MeshInstance3D under a node (recursive).
func _mesh_instances(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_mesh_instances(c, acc)
	return acc
