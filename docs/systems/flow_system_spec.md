# Scene Flow & Timing — Design Spec

Status: **v1 implemented.** Per-scene orchestration (dialogue, camera moves, hints,
highlights, NPC walks, waiting on player actions) is now authored as a readable
top-to-bottom "screenplay" via `SceneFlow`, and all the shared timing lives in one
`Timing` autoload. Scene 1's opening is fully converted (`scene1_flow.gd`), and the
old bespoke `guide.gd` + the intro-camera/hint code that lived in `world.gd` are
gone.

Files: `scripts/scene_flow.gd` (base, incl. the order-independence helpers),
`scripts/scene1_flow.gd` (example), `scripts/timing.gd` (`Timing` autoload),
`scripts/game_state.gd` (`GameState` autoload — persistent flags + day). Touched:
`world.gd` (removed hint orchestration, added `first_ball()`/`first_crate()`),
`interactable.gd` (`has_talked()`), `dialogue_box.gd` and `iso_camera.gd` (read
speeds from `Timing`), `start_menu.gd` (`GameState.reset()` on New Game),
`scene1.tscn`, `project.godot`.

## Why

Sequencing beats and timing them used to be hand-coded in scattered spots. Now a
scene's flow reads like a script, gating on real events (`await until(...)`), and
the global feel (text speed, camera pans, standard pauses) is tuned in one place.

## Order-independence (the important part)

A linear `await` screenplay assumes the world is pristine when each beat runs. It
isn't: **the player can act ahead of the script** — shove the crate before being
asked, talk early, skip the ball. The original scene 1 broke exactly here: the crate
beat read `tile_of(crate)` *when it ran* (after the villager talk), so if you'd
already pushed the crate into the water it (1) highlighted the crate mid-pond and
(2) waited forever for a crate that can't be pushed again — a stranded outline and a
dead scene.

The rule now: **every gate asks "is this ALREADY done?" first.** If yes, skip it —
no outline, no wait, no deadlock. If no, set up the affordances (highlight / hint /
arrow), wait, then tear them down. Three pieces make this work:

1. **Objectives are LIVE predicates, not script state.** `objective(&"crate_moved",
   func(): return has_moved(crate))` reads real world state, so it's correct whether
   or not the flow was watching when it happened.
2. **Snapshot origins up front.** `mark_start(crate)` in `_run()` records the true
   start tile, so `has_moved()` measures from the origin — never from wherever a beat
   first happens to look.
3. **`beat({...})` is the affordance bundle.** It no-ops when the objective is already
   satisfied; otherwise it shows what you pass and cleans it all up on completion.

```gdscript
mark_start(crate)
objective(&"crate_moved", func(): return has_moved(crate))
await beat({"objective": &"crate_moved", "highlight": crate})   # safe in any order
```

Run beats concurrently (call the coroutine **without** `await`) so they're also
order-independent *relative to each other* — scene 1 does this for the ball vs. the
villager.

### Adapt vs. prevent

Default to **adapt**: tolerate whatever the player already did. Only **prevent** an
action when doing it early is genuinely **unrecoverable** (soft-locks the game).
Prefer making the situation recoverable (respawn/retrieve the prop) over locking
input, which feels bad and means disabling systems mid-scene. When you must prevent,
gate it at the source — e.g. add a check in `world.can_enter()` keyed on a
`GameState` flag — not by freezing the player. In scene 1 nothing is unrecoverable:
any crate move counts, so no prevention is needed.

### GameState (persistent flags + day)

`GameState` (autoload) is the persistent story record — `current_day` plus story
flags — kept separate from any flow's script position. Flows set flags at meaningful
beats (`GameState.set_flag(&"s1_crate_crossed")`) and can branch on them
(`GameState.has_flag(...)`). Flags persist across the scenes of a run (the 9-day
loop) and are wiped by `GameState.reset()` on **New Game** (not on a scene retry).
For physical props, prefer a live predicate (`has_moved`) over a flag; use flags for
facts with no live world readout (dialogue seen, day completed).

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
| `until_tile_changes(node, from_tile)` | Wait until a crate/ball leaves a tile. *Prefer `has_moved` / a "moved" objective — those measure from the origin and never deadlock on an already-done push.* |
| `mark_start(node)` | Record a prop's start tile (call in `_run()` setup) so `has_moved` measures from the origin. |
| `has_moved(node)` | True if a marked prop left its start tile (or was freed). |
| `objective(id, cond)` | Register a named objective as a LIVE predicate `func() -> bool`. |
| `is_done(id)` | Is a registered objective satisfied right now? (Use to skip beats.) |
| `complete(id, sig_obj?, sig?)` | Await an objective; returns instantly if already done. |
| `until_true(cond, sig_obj?, sig?)` | Await any predicate; returns instantly if already true. Never deadlocks on an action already performed. |
| `beat({...})` | Run one objective beat: no-op if already done, else show affordances (`highlight` / `hint` / `arrow`), wait (poll or on `signal`), tear down. |
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

## Authoring checklist for a new scene (order-safe)

1. In `_run()` setup, `mark_start()` every movable prop the flow watches.
2. `objective(&"id", func(): return <live predicate>)` for each gate — read world /
   `GameState`, never a snapshot.
3. Gate each beat with `await beat({"objective": &"id", ...})`; skip optional intro
   flourishes with `if not is_done(&"id")`.
4. Set a `GameState` flag at each meaningful beat for later branching.
5. Run independent beats concurrently (no `await`) so their order doesn't matter.
6. Only add prevention (a `can_enter`/interaction guard on a flag) for actions that
   would be *unrecoverable* if done early.

## Deferred / future

- **`ask()` player choices** — the signature is in place; needs the choice UI in the
  dialogue box (which already reserves room) and a return value.
- **Flag-branched dialogue** — `Interactable.get_lines()` could pick lines by
  `GameState.has_flag(...)` / `current_day` (the after-lines switch is the simple
  version of this today).
- **Data-authored flows** — if inspector/no-code authoring is wanted later, a Step
  resource list can drive the same API as its runtime.
