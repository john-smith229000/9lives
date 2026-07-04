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

## Tile mode (scenes 1–4): one blade per sub-grid cell of each grass tile.
func setup(world: World, player: Node3D, grid_root: Node3D, tiles: Array[Vector2i]) -> void:
	_world = world
	_player = player
	_grid_root = grid_root
	var meshes := _blade_meshes()
	if meshes.is_empty():
		push_warning("GrassField: no blade meshes (models/blade1.glb ...) found — no grass.")
		return
	_build(meshes, _scatter_tiles(meshes, tiles))

## Mesh mode (scene 5): scatter blades directly over world-space triangles (`tris`,
## groups of 3) at `density` blades per m², so grass follows the surface exactly
## with no per-tile gaps. Movement + bending stay tile-based (bins below).
func setup_mesh(world: World, player: Node3D, grid_root: Node3D, tris: PackedVector3Array, density: float) -> void:
	_world = world
	_player = player
	_grid_root = grid_root
	var meshes := _blade_meshes()
	if meshes.is_empty():
		push_warning("GrassField: no blade meshes (models/blade1.glb ...) found — no grass.")
		return
	_build(meshes, _scatter_mesh(meshes, tris, density))

## Fill one transform list per blade variant by scattering over the grass tiles
## (with jitter), each blade on the tile's interpolated surface height.
func _scatter_tiles(meshes: Array, tiles: Array[Vector2i]) -> Array:
	var cell := _world.cell_size
	var rng := RandomNumberGenerator.new()
	var lists: Array = []
	for _m in meshes:
		lists.append([])
	for tile in tiles:
		if tile.x < 0 or tile.x >= _world.grid_size or tile.y < 0 or tile.y >= _world.grid_size:
			continue
		var top := _world.get_elevation(tile.x, tile.y) + 0.5
		var cols := maxi(int(ceil(sqrt(float(_world.grass_per_tile)))), 1)
		var sub := cell / float(cols)
		var origin_x := tile.x * cell - cell * 0.5
		var origin_z := tile.y * cell - cell * 0.5
		for i in _world.grass_per_tile:
			var cx := origin_x + (float(i % cols) + 0.5) * sub
			var cz := origin_z + (float(i / cols) + 0.5) * sub
			var sxz := _world.grass_scale * rng.randf_range(0.85, 1.15)
			var sy := _world.grass_scale * maxf(0.3, 1.0 + rng.randf_range(-_world.grass_height_variation, _world.grass_height_variation))
			var t := Transform3D.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU)
			t = t.scaled(Vector3(sxz, sy, sxz))
			var wx := cx + rng.randf_range(-0.5, 0.5) * sub * _world.grass_jitter
			var wz := cz + rng.randf_range(-0.5, 0.5) * sub * _world.grass_jitter
			t.origin = Vector3(wx, _world.grass_surface_y(wx, wz, top), wz)
			(lists[rng.randi() % meshes.size()] as Array).append(t)
	return lists

## Fill one transform list per blade variant by scattering uniformly over the mesh
## triangles at `density` blades per m² (blades sit exactly on the surface).
func _scatter_mesh(meshes: Array, tris: PackedVector3Array, density: float) -> Array:
	var rng := RandomNumberGenerator.new()
	var lists: Array = []
	for _m in meshes:
		lists.append([])
	var n_tri := tris.size() / 3
	for ti in n_tri:
		var a := tris[ti * 3]
		var b := tris[ti * 3 + 1]
		var c := tris[ti * 3 + 2]
		var n := int(round(0.5 * (b - a).cross(c - a).length() * density))
		for _k in n:
			var r1 := rng.randf()
			var r2 := rng.randf()
			if r1 + r2 > 1.0:
				r1 = 1.0 - r1
				r2 = 1.0 - r2
			var sxz := _world.grass_scale * rng.randf_range(0.85, 1.15)
			var sy := _world.grass_scale * maxf(0.3, 1.0 + rng.randf_range(-_world.grass_height_variation, _world.grass_height_variation))
			var t := Transform3D.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU)
			t = t.scaled(Vector3(sxz, sy, sxz))
			t.origin = a + (b - a) * r1 + (c - a) * r2
			(lists[rng.randi() % meshes.size()] as Array).append(t)
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

## The mesh from each of models/blade1.glb .. blade5.glb that exists, with its
## node transform (Blender rotation/scale) baked into the geometry — so the raw
## MultiMesh mesh is upright and correctly sized even if transforms weren't applied
## on export (otherwise a rotated/oversized node makes the blades huge and sideways).
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
		add_child(inst)                        # so global_transform resolves
		var mesh: Mesh = null
		for m in _mesh_instances(inst):
			var mi := m as MeshInstance3D
			if mi.mesh:
				mesh = _bake_mesh(mi.mesh, mi.global_transform)
				break
		remove_child(inst)
		inst.queue_free()
		if mesh:
			out.append(mesh)
	return out

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
	m.set_shader_parameter("wind_strength", _world.grass_wind_strength)
	m.set_shader_parameter("wind_speed", _world.grass_wind_speed)
	m.set_shader_parameter("sway_scale", _world.grass_sway_scale)
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
	return m

func _process(delta: float) -> void:
	if not _active.is_empty() or (not _bins.is_empty() and _player):
		_update(delta)

## Per-blade grass wake: fade any flattened blades on their own timer, then press
## the grass on the tile under the cat. Only stepped tiles flatten and each recovers
## independently — a settling trail of footprints, no radius/sphere, no wave. Skips
## while airborne so a jump only flattens its takeoff and landing tiles.
func _update(delta: float) -> void:
	var fade := delta / maxf(_world.grass_recovery, 0.05)
	var dead: Array = []
	for gid in _active:
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
	var press := delta / maxf(_world.grass_press_time, 0.01)
	# The cat presses the grass on the tile it stands on (only while grounded, so a
	# jump only flattens its takeoff/landing tiles). Single tile — unchanged.
	if _player and not (_player.has_method("is_airborne") and _player.is_airborne()):
		var cell: float = _world.cell_size
		var p := _player.global_position
		# Cat: single tile, soft (linear) footprint — unchanged from before.
		_press_tile(Vector2i(roundi(p.x / cell), roundi(p.z / cell)), p, maxf(_world.grass_footprint, 0.05), press, 0.0)
	# Pushed crates and rolling balls flatten grass under them too — a solid, fully
	# flat patch (plateau falloff) over a wider area, across every tile they overlap,
	# so they bend the grass more than the cat and leave a clear trail.
	for a in _world.grass_pressers():
		_press_area(a["pos"], a["radius"], press)

## Press the blades on a single tile toward flat, splayed away from `pos`. `inner`
## is the fraction of `radius` that stays fully flat (1.0) before the edge tapers:
## 0.0 = a soft linear footprint (the cat), higher = a solid flattened patch.
func _press_tile(tile: Vector2i, pos: Vector3, radius: float, step: float, inner: float) -> void:
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
		var dir := off.normalized() if d > 0.0001 else Vector2(0, 1)
		var cur: float = (_active[gid] as Vector3).x if _active.has(gid) else 0.0
		var amt := minf(cur + step, target) if cur < target else cur
		_active[gid] = Vector3(amt, dir.x, dir.y)
		_write(gid, amt, dir)

## Press all tiles a `radius` reaches (so crates/balls flatten across tile edges
## and leave a trail). Uses a plateau falloff (solid flat patch).
func _press_area(pos: Vector3, radius: float, step: float) -> void:
	var cell: float = _world.cell_size
	var reach := maxi(int(ceil(radius / cell)), 0)
	var ctile := Vector2i(roundi(pos.x / cell), roundi(pos.z / cell))
	for tx in range(ctile.x - reach, ctile.x + reach + 1):
		for tz in range(ctile.y - reach, ctile.y + reach + 1):
			_press_tile(Vector2i(tx, tz), pos, radius, step, 0.6)

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
