# Scene Flow & Timing — Design Spec

Status: **v1 implemented.** Per-scene orchestration (dialogue, camera moves, hints,
highlights, NPC walks, waiting on player actions) is now authored as a readable
top-to-bottom "screenplay" via `SceneFlow`, and all the shared timing lives in one
`Timing` autoload. Scene 1's opening is fully converted (`scene1_flow.gd`), and the
old bespoke `guide.gd` + the intro-camera/hint code that lived in `world.gd` are
gone.

Files: `scripts/scene_flow.gd` (base), `scripts/scene1_flow.gd` (example),
`scripts/timing.gd` (`Timing` autoload). Touched: `world.gd` (removed hint
orchestration, added `first_ball()`/`first_crate()`), `dialogue_box.gd` and
`iso_camera.gd` (read speeds from `Timing`), `scene1.tscn`, `project.godot`.

## Why

Sequencing beats and timing them used to be hand-coded in scattered spots. Now a
scene's flow reads like a script, gating on real events (`await until(...)`), and
the global feel (text speed, camera pans, standard pauses) is tuned in one place.

## Authoring a new scene's flow

1. Create `my_scene_flow.gd`:

   ```gdscript
   extends SceneFlow

   func _run() -> void:
       var npc := world.get_node_or_null("Elder")
       await say("Elder", ["Welcome, traveller."])
       await camera_hold(world.first_ball())        # linger, pan there, pan back
       await until(npc.get_node("Talk"), "talked")  # wait for the player
       await move_npc(npc, world.ball_goal_tile())   # walk, wait for arrival
   ```

2. Add it as a **child of the scene's `World` node** (any name, e.g. `Flow`).
3. Reference **scene nodes** with `world.get_node_or_null("Name")`; get **procedural
   objects** (balls, crates, the goal tile) from `world` accessors.

That's the whole setup — the base resolves `world` / `camera` / `player` and runs
`_run()` after the world has spawned.

## The API (all `await`-able unless noted)

| Call | Does |
|---|---|
| `wait(seconds = default)` | Pause. Defaults to `Timing.default_wait`. |
| `say(speaker, lines)` | Show speech, wait until it closes. `lines` = String or Array. |
| `ask(speaker, prompt, choices)` | **Reserved** for player choices (returns index; not implemented yet — shows the prompt for now). |
| `hint(text)` / `hide_hint()` | Non-blocking tip banner (not awaited). |
| `camera_focus(node)` / `camera_release()` | Pan to a node / back to the cat (not awaited). |
| `camera_hold(node, pre, hold)` | Linger on the cat, pan to `node`, linger, pan back. Times default to `Timing`. |
| `highlight(node)` / `unhighlight(node)` | Pulsing outline (style from `Timing`). |
| `until(obj, "signal")` | Wait for a signal (e.g. an Interactable's `talked` / `conversation_ended`). |
| `until_tile_changes(node, from_tile)` | Wait until a crate/ball leaves a tile (a "push"). |
| `tile_of(node)` | The grid tile a node is on. |
| `move_npc(npc, goal_tile, adjacent = true)` | Walk a placed NPC to (a tile next to) the goal, follow terrain, wait for arrival. |
| `spawn_arrow(over)` | Float a self-bobbing arrow over a node; returns it so you can `queue_free()` it. |

**Concurrency:** call a coroutine method **without** `await` to run it alongside the
main flow; `await` it to run in sequence. Scene 1 uses this: the ball-push watcher
(clear hint → later show an arrow) runs concurrently with the villager beat, so the
player can do them in either order.

## Timing presets

`Timing` (autoload) holds the shared knobs, read by Dialogue, the camera, and flows:
`text_cps`, `hint_cps`, `hint_fade`, `camera_pan_smooth`, `camera_pre_hold`,
`camera_hold`, `default_wait`, `npc_walk_speed`, the `arrow_*` values, and the
`outline_*` style. Tune the game's overall feel here; pass explicit args to a flow
call to override a single beat. (You could later swap whole profiles for e.g. a
"snappy" vs "cinematic" feel.)

## World hooks a flow relies on

`world.first_ball()`, `world.first_crate()`, `world.ball_goal_tile()`,
`world.find_path_min_turns()`, `world.path_walkable()`, `world.get_elevation()`,
`world.ground_y`, `world.cell_size`. Interactables expose `talked`,
`conversation_ended`, and `use_after_lines()`.

## Deferred / future

- **`ask()` player choices** — the signature is in place; needs the choice UI in the
  dialogue box (which already reserves room) and a return value.
- **`GameState`** (current_day + flags) so flows and `Interactable.get_lines()` can
  branch on story state (the 9-day loop). Flows are written assuming this arrives.
- **Data-authored flows** — if inspector/no-code authoring is wanted later, a Step
  resource list can drive the same API as its runtime.
