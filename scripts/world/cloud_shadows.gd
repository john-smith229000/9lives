extends Node
class_name CloudShadows
## Whole-scene cloud shadows. Created at runtime by World when cloud_shadows_enabled
## is on. Builds one shared blend_mul overlay material (cloud_overlay.gdshader) and
## attaches it as the `next_pass` of every environment mesh's material, so a single
## drifting noise pattern dims the ground, buildings, water and props together. The
## grass bakes the same effect into its own shader (grass_wind.gdshader), so grass
## MultiMeshes are intentionally skipped here.
##
## Skipped, on purpose:
##  - Grass MultiMeshInstance3D (handled in the grass shader; also not a MeshInstance3D).
##  - Skinned characters (under a Skeleton3D / CharacterBody3D): a plain next_pass
##    doesn't skin, so it would shadow the rest pose. Small, moving, rarely lingering
##    under a cloud edge — not worth the extra skinned overlay shader.
##  - Outline hull children (Outline._NAME): the rim shouldn't be multiplied.

const _OVERLAY_SHADER: Shader = preload("res://shaders/cloud_overlay.gdshader")
const _OUTLINE_HULL := "__outline_hull"

var _overlay: ShaderMaterial

## Attach the overlay to every eligible mesh under `root`. Call once, LAST in the
## scene build (after keyhole swaps its building materials in), so we set next_pass
## on whatever material is actually active.
func setup(world: World, root: Node) -> void:
	if not world.cloud_shadows_enabled:
		return
	_overlay = ShaderMaterial.new()
	_overlay.shader = _OVERLAY_SHADER
	world.apply_cloud_params(_overlay)
	_walk(root)

func _walk(node: Node) -> void:
	# Don't descend into skinned characters — their meshes need skinning the overlay
	# doesn't do. (Grass MultiMeshInstance3D isn't a MeshInstance3D, so it's skipped
	# automatically.)
	if node is Skeleton3D or node is CharacterBody3D:
		return
	if node is MeshInstance3D and node.name != _OUTLINE_HULL:
		_apply(node as MeshInstance3D)
	for c in node.get_children():
		_walk(c)

func _apply(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		if mat == null:
			# No material at all: give the surface a plain matte one just so the
			# overlay has something to chain from.
			mat = StandardMaterial3D.new()
			mi.set_surface_override_material(s, mat)
		if mat == _overlay or mat.next_pass == _overlay:
			continue                        # already carrying the clouds (shared mats)
		mat.next_pass = _overlay
