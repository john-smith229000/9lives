# Dialogue & Interaction — Design Spec

Status: **v1 implemented** — walk up to an interactable, press **I**, and its
lines play in a bottom-center box with a typewriter reveal; press **I** to advance
(and again to close). Non-blocking **hints** share the same UI. A talkable
stationary villager and the rolling-ball hint are wired into scene 1 as the first
content.

Touched files: `project.godot` (the `interact` action on **I**, the `Dialogue`
autoload), `scripts/dialogue.gd`, `scripts/dialogue_box.gd`,
`scripts/interactable.gd`, `scripts/interaction.gd`, `scripts/world.gd`,
`scripts/player.gd`, `scripts/iso_camera.gd`, `scenes/scene1.tscn`.

## Intent

Give the cat a way to talk to NPCs and objects, and a way to surface tips, without
breaking the deterministic tile-based movement. This is the foundation the story
(see `STORY.md`) sits on — every conversation, clue, and quest prompt flows
through it.

## Core principle

Interaction targets a **tile**, exactly like jump and push do. The cat can talk to
whatever sits on the tile it faces (`grid + facing`). No proximity radius, no
raycast — deterministic and consistent with the rest of the movement model.

## The two text modes

- **Speech** — a *blocking* conversation. `Dialogue.is_active()` is true, so the
  player, click-to-move, and the camera all freeze their input for the duration.
  Advance / skip-the-typewriter / close with **I**.
- **Hint** — a *non-blocking* banner (e.g. the rolling-ball tip). Movement is
  **not** frozen, so a hint can point at something the player then walks over and
  does. Dismissed programmatically (e.g. when the ball is first shoved) or by
  pressing **I** when not facing anything.

## Input

- **Key:** **I** (the `interact` action). Chosen so it doesn't collide with the
  camera's Q/E rotation. Space stays jump.
- The `InteractionController` is added to the tree *after* the camera, so its
  `_unhandled_input` runs first and **consumes** the key when it opens a
  conversation — talking can never also nudge the camera.
- During speech the `Dialogue` autoload handles **I** (advance); the camera is
  guarded by `Dialogue.is_active()` so it ignores all input meanwhile.

## Components

| Piece | Role |
|---|---|
| `Dialogue` (autoload, `dialogue.gd`) | Owns the single on-screen box + conversation state. `start_speech(speaker, lines, on_close)`, `show_hint`/`hide_hint`, `is_active()`. Advances speech on **I**. |
| `dialogue_box.gd` (`CanvasLayer`) | The UI, built in code (no scene-anchor gotchas): a bottom-center speech panel with a typewriter reveal + an `[I] ▸` continue cue, and a lighter hint banner above it. |
| `Interactable` (`interactable.gd`) | Drop under an NPC/prop to make it talkable. Holds `speaker` + `lines` (edited in the inspector), reports its tile, and can turn the owner's `Model` to face the cat. |
| `InteractionController` (`interaction.gd`) | Spawned by World. On **I**, if the cat faces an `Interactable`, opens its conversation. Also snaps talkable NPCs to the ground surface at setup. |

## How Player talks to the system

Consistent with the provider pattern, the coupling is minimal: Player exposes
`grid_tile()` and `facing_dir()`, and freezes itself when `Dialogue.is_active()`.
World spawns the `InteractionController` in `_ready()` (config stays on World), and
gates its click-to-move on the same flag. The camera adds one guard line. Nothing
reaches into a specific scene.

## Authoring content

Lines live on the `Interactable` node as exported strings — write/edit them in the
Godot inspector, one entry per press-to-advance screen. To add a talker: instance
an NPC (or any Node3D with a `Model` child), add an `Interactable` child, and fill
in `speaker` + `lines`. Set `snap_to_surface` (default on) to auto-place it on the
terrain. Hints are triggered from code (see the ball hint) via
`Dialogue.show_hint(text)` / `hide_hint()`; `world.gd` exposes `hint_ball_text`.

## Case table

| Situation | Result |
|---|---|
| Face an interactable, press **I** | Its conversation opens; movement/camera freeze |
| Mid-line, press **I** | Typewriter completes instantly (shows the whole line) |
| Line fully shown, press **I** | Advance to the next line |
| Last line, press **I** | Conversation closes; input resumes; `on_close` fires |
| Press **I** facing nothing, hint showing | Hint dismissed |
| Press **I** facing nothing, no hint | Nothing (event falls through) |
| Ball hint at level start | Banner shows `hint_ball_text`; clears when the ball is first shoved |

## Known rough edges / deferred

- **Branching / choices.** v1 is linear. The natural next step is a `choices`
  option on a line that jumps to a labelled line — the box already reserves room
  for a choice list.
- **JSON content files.** Lines are inspector strings today; a `dialogues/*.json`
  loader keyed by id would scale better once there are many conversations (and
  ties into the day-loop: which lines play depends on `current_day`/flags).
- **Per-NPC model facing.** `face_toward` assumes the `+Z`-facing convention (adds
  PI, like `npc.gd`); a future model facing `-Z` would need its own offset.
- **Portraits / speaker colour, text SFX, an advance indicator blink** — polish.
- **Controller/gamepad + a click-to-advance** binding for the box.

## Build order

1. ✅ `interact` action + `Dialogue` autoload + typewriter box.
2. ✅ `Interactable` + `InteractionController`; input freeze + camera guard.
3. ✅ First content: scene-1 villager (crate-float tip) + rolling-ball hint.
4. ⬜ Branching choices.
5. ⬜ JSON content keyed to the day-loop; portraits/polish.
