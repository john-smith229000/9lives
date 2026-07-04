# 9lives — Architecture

A short map of how the project fits together, so future changes are easy to place.

## Folders

- `scenes/` — Godot scenes (`.tscn`)
- `scripts/` — GDScript
- `models/` — `.glb` art (characters, props, the beveled tile set, level maps)
- `shaders/` — `.gdshader` files

## Entry point & scene flow

- Main scene (see `project.godot`): `scenes/start_menu.tscn`. The menu buttons and the pause menu route through the **`SceneManager`** autoload (`goto_level`, `goto_menu`, …) — the single place that loads scenes.
- **All four levels inherit from `scenes/level_base.tscn`** (Godot scene inheritance). The base holds the shared skeleton — **World** (`world.gd`) + **Grid** + **WorldEnvironment** + **Sun** + **Player** (`player.tscn`) + **Camera** (`iso_camera.gd`) + **PauseMenu** — with neutral defaults. Each `sceneN.tscn` only stores its *deltas*: World's config exports, any Sun/Camera/Player/Environment value that differs from the base, and its own extra nodes (map/house/buildings).
- `scene1` — procedural terrain (smooth mesh), grass everywhere, a water pond, a jump-over hole, pushable crates, a ball.
- `scene2` — a house (`house1.tscn` + `house_controller.gd` doorway trigger) with the keyhole see-through effect.
- `scene3` — custom map + buildings (`scene3_*.glb`), a background NPC that roams.
- `scene4` — custom map (`scene4.glb`), grass auto-placed from a painted color, day/night cycle, fully-matte ground.

## Scripts

| Script | Role |
|---|---|
| `world.gd` | `class_name World`. The hub for a level: builds the board (terrain/tiles), owns the movement rules (`can_enter`, pushing, click-to-move pathing), crates/water, the goal, holes, balls, and wires the player. Delegates self-contained subsystems to the runtime component nodes below. |
| `player.gd` | Grid-tile movement, jumping/mounting, pushing crates. Scene-agnostic — it asks the World through *providers* (see below). |
| `iso_camera.gd` | Isometric follow camera with a `focus_on()` / `release_focus()` override (used by hints). |
| `npc.gd` | The roaming background character itself (movement + walk animation). Gets its nav from `NpcDirector`. |
| `outline.gd` | Reusable `class_name Outline` — inverted-hull outline used to highlight an object. |
| `day_phase.gd` | `class_name DayPhase` resource: one preset (sun angle/energy/color, ambient, sky) for the day/night cycle. |
| `house_controller.gd` | Doorway trigger for the scene 2 house. |
| `scene_manager.gd` | `SceneManager` **autoload**. Owns all scene loading/transitions (`goto_level`, `goto_menu`, `goto_next_level`, `reload`); always unpauses first. |
| `pause_menu.gd`, `start_menu.gd` | UI; both route scene changes through `SceneManager`. |

### Adding a new level

Create it as an **inherited scene** of `level_base.tscn` (Scene ▸ New Inherited Scene), set the World config exports + add any map/props, and add its path to `SceneManager.LEVELS`. No node structure to copy.

### Runtime component nodes (spawned by World)

Each of these is its own script that World instantiates as a child in `_ready()` when the relevant feature is enabled. The **config exports stay on the World node** (so the scenes are configured exactly as before) and are read by the component through a reference to World; the component owns that feature's state and its own `_process`. This is what keeps `world.gd` focused on the board itself.

| Script | Created when | Owns |
|---|---|---|
| `day_night.gd` (`DayNightCycle`) | `day_night_enabled` | The Sun + WorldEnvironment easing through `DayPhase` presets; the `T` (cycle_time) key. |
| `keyhole_effect.gd` (`KeyholeEffect`) | `enable_keyhole` | See-through building materials + the per-frame occlusion test. World supplies the building roots via `_keyhole_roots()`. |
| `npc_director.gd` (`NpcDirector`) | `npc_enabled` | Spawns the NPC; owns its walkable-tile set + BFS pathfinding. Queries World's shared obstacle map (`ensure_obstacle_map` / `is_map_obstacle`). |
| `grass_field.gd` (`GrassField`) | grass tiles exist | Blade scatter (MultiMeshes), the wind material, and the per-blade footprint interaction. World picks the tiles + supplies `grass_surface_y()`. |

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

Grouped under `# --- Section ---` headers: terrain build (grid + beveled/box/smooth tiles), Holes, Water, Grass (tile selection only — blades live in `GrassField`), Pushable blocks + crate/water floating, Click-to-move + `can_enter` movement rules, Background NPC (obstacle-map accessors), Goal pads, Keyhole roots, Rolling balls, Hint spotlight.

## What's been modularized (and what's left)

The self-contained subsystems have been pulled into the runtime component nodes above (day/night, keyhole, NPC, grass), taking `world.gd` from ~2000 to ~1570 lines. What remains in `world.gd` is the **cohesive core board logic**: terrain generation, the tile grid, the movement/pushing rules (`can_enter`), crates + water floating, the goal, holes, and balls. These are tightly interwoven (they all read/mutate the same tile/height/block state and feed the player's movement), so they're best kept together rather than split further.

If a future feature is genuinely independent, follow the same pattern: a new component script that World spawns in `_ready`, with config exports staying on World, and test in Godot after wiring it.
