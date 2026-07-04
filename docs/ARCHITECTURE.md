# 9lives — Architecture

A short map of how the project fits together, so future changes are easy to place.

## Folders

- `scenes/` — Godot scenes (`.tscn`)
- `scripts/` — GDScript
- `models/` — `.glb` art (characters, props, the beveled tile set, level maps)
- `shaders/` — `.gdshader` files

## Entry point & scene flow

- Main scene (see `project.godot`): `scenes/start_menu.tscn` → `start_menu.gd` buttons call `change_scene_to_file` to load `scene1`–`scene4`.
- Every level scene is the same shape: a **World** node (`world.gd`) + **Player** (`player.tscn`) + **Camera** (`iso_camera.gd`) + **PauseMenu** (`pause_menu.tscn`).
- `scene1` — procedural terrain (smooth mesh), grass everywhere, a water pond, a jump-over hole, pushable crates, a ball.
- `scene2` — a house (`house1.tscn` + `house_controller.gd` doorway trigger) with the keyhole see-through effect.
- `scene3` — custom map + buildings (`scene3_*.glb`), a background NPC that roams.
- `scene4` — custom map (`scene4.glb`), grass auto-placed from a painted color, day/night cycle, fully-matte ground.

## Scripts

| Script | Role |
|---|---|
| `world.gd` | The hub for a level. Builds the board, spawns everything (terrain, crates, ball, hole, water, grass, goal, NPC), runs day/night and the keyhole effect, and wires the player. Large; organized by `# --- Section ---` headers. |
| `player.gd` | Grid-tile movement, jumping/mounting, pushing crates. Scene-agnostic — it asks the World about the world through *providers* (see below). |
| `iso_camera.gd` | Isometric follow camera with a `focus_on()` / `release_focus()` override (used by hints). |
| `npc.gd` | Background character that wanders a scene avoiding buildings. |
| `outline.gd` | Reusable `class_name Outline` — inverted-hull outline used to highlight an object. |
| `day_phase.gd` | `class_name DayPhase` resource: one preset (sun angle/energy/color, ambient, sky) for the day/night cycle. |
| `house_controller.gd` | Doorway trigger for the scene 2 house. |
| `pause_menu.gd`, `start_menu.gd` | UI. |

## The provider pattern (how Player talks to World)

`player.gd` never reaches into a specific scene. In `world.gd._ready()` the World hands the Player a set of `Callable`s:

- `height_provider = get_elevation` — terrain height of a tile
- `block_handler = can_enter` — may the cat move onto/through a tile (crates, water, holes, balls)
- `surface_provider = surface_elevation` — standing height incl. a crate on top
- `block_provider = has_block`, `hole_provider = has_hole`, `water_provider = has_water`, `occupied_provider = _is_pushable_tile`

This keeps the Player identical across all four levels.

## Coordinate conventions

- Tile `(x, z)` sits at world `(x * cell_size, y, z * cell_size)`; `cell_size = 1`.
- `ground_y = 1.0`. A tile's **walkable top surface** is at world-Y `get_elevation(x, z) + 0.5`.
- Player, grass, and crates all align to that surface height.

## Terrain (procedural scenes)

`generate_terrain` builds per-tile heights from noise. Three ground render modes (mutually exclusive):

1. **Beveled tile set** (default) — picks `no_bev`/`one_bev`/…/`full_bev` per tile so exposed edges are beveled.
2. **`plain_box_tiles`** — one flat-colored box per tile.
3. **`smooth_terrain`** — a single continuous mesh sloping between tile heights, with dirt side-walls at the map edge / water / holes. Used in scene 1.

## Grass

`world.gd._spawn_grass()` scatters `models/blade1.glb`–`blade5.glb` as MultiMeshes driven by `shaders/grass_wind.gdshader`. Placement modes:

- `grass_on_all_tiles` — every ground tile (scene 1)
- `grass_from_paint` — tiles whose map-texture color matches `grass_paint_color` (scene 4)
- else the explicit `grass_tiles` list

**Player interaction** is per-blade: as the cat walks, the tile it stands on is stamped into each blade's MultiMesh *custom data* (bend amount + push direction), and each blade fades back on its own timer — so footprints trail and recover with no travelling "wave". Jumps only stamp the takeoff/landing tiles (`player.is_airborne()`).

## Shaders

- `grass_wind.gdshader` — wind sway, per-blade footprint bend (from custom data), per-blade color variation, sun-kissed tips, and soft "wrap" lighting so the shadow side isn't crushed.
- `keyhole.gdshader` — see-through buildings when one sits between the camera and the cat.

## `world.gd` section map

State and spawners are grouped under headers: Goals, Balls, Hint, Grass, Day/night (state near the top); then Holes, Water, Grass (blades), Pushable blocks, Click-to-move, Background NPC, Goal, Keyhole see-through, Hint spotlight, Day/night cycle, Rolling balls.

## If `world.gd` keeps growing

It's a deliberate hub, but if it gets unwieldy the safe path is to extract one self-contained subsystem at a time into a child-node component script (candidates, roughly independent: grass, day/night, keyhole, NPC, water+crates), moving its state and `_process` slice with it — and testing in Godot between each extraction. Avoid doing several at once.
