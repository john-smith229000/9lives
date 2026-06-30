# Jump Mechanic — Design Spec

Status: design / not yet implemented
Scope: grid (isometric) movement. Interior free-movement mode is handled separately.

## Intent

Add a jump to the cat, triggered by the **space bar**, that feels intuitive and stays true to the game's deterministic, tile-based puzzle movement. The cat always lands on a whole tile — no mid-tile or on-edge landings — so existing systems (`can_enter`, `is_tile_blocked`, `find_path`) keep working.

## Core principle

A jump is **not** a free physics arc. It's a special movement segment that targets a tile, reusing the existing `_begin_segment` / `_advance` glide, but with a **parabolic Y arc** instead of terrain-riding. Because the target is always a tile, the grid invariants are preserved.

This collapses "vertical jumps of different heights" and "horizontal jumps" into one thing: **pick the target tile, derive the arc.** The arc's apex is computed from the up-delta and the horizontal distance; heights are never hand-authored.

## The two verbs (key mental model)

The player should learn one simple distinction:

- **Walk** off an edge → you step or fall *down*. This is how you descend on purpose.
- **Jump** → you *traverse*: you reach across to a foothold, preferring a landing at (or up to) your current level, and only fall if there's no such foothold ahead.

Once a player internalizes "jump = reach across, walk = go down," every situation is predictable.

## Input

- **Key:** Space bar.
- **Tap only** for now. (Hold-to-vault is a deferred, principled future addition — see Mount vs Vault.)
- **Direction:** the currently held movement direction; if none is held, the jump has no direction.

## Target resolution rule

On tap, **with a direction held**, scan in priority order:

1. **Land ahead (dist 1).** If the tile directly ahead has a surface that is level, or up within `max_jump_up`, and has headroom → land there. Covers: flat hop forward, step up a ledge, mount a short crate.
2. **Leap across (dist 2).** If the tile directly ahead is a drop or a gap (no level-or-up footing), peek one tile further. If it has a level-or-up foothold → leap across to it. Covers: clearing a hole, and crate → gap → crate.
3. **Drop forward (dist 1).** If nothing level-or-up is reachable, drop forward onto the nearest lower tile.
4. **In-place pop.** No direction held, or no valid landing (e.g. a wall taller than `max_jump_up`) → the cat hops in place and stays put.

The preference is **height-aware**: footholds at or above the current level beat falling. That's what makes the crate-to-crate-across-a-gap leap work instead of dropping into the gap.

## Support height (new concept)

Today the cat's height always comes from terrain (`get_elevation(x, z)`). Crates are pushable obstacles, not terrain, so "standing on a block" isn't modeled.

The jump needs a notion of **current support height** = terrain elevation **or** the top of a block sitting on the current tile.

- Mounting a crate sets support height to the crate top.
- Walking off → the destination tile has no block, support reverts to terrain, and existing height-riding eases the cat down. No second jump press is needed to get off a crate.

## Mount vs vault

For a short obstacle (e.g. a 1 m crate) a jump toward it has two possible endings:

- **Mount** — end up standing *on top of* the crate. **Default on tap.**
- **Vault** — clear *over* it and land on the far tile; the crate stays behind you. **Deferred.**

These only differ for an obstacle short enough to land on. A wall taller than `max_jump_up` can be neither mounted nor cleared → in-place pop.

Levers:

- Whether a crate is mountable is decided by `max_jump_up` vs its height.
- To make crates never act as platforms (always vault), flag them **non-standable** so resolution skips them at step 1.
- **Hold-to-vault** is the natural future control: this crate case is the one genuine ambiguity (two valid landings in the same direction), so reserving the hold gesture for it is principled. Not built yet.

## Case table (direction held unless noted)

| Situation | Result |
|---|---|
| Flat ground ahead | Hop one tile forward |
| Ledge up, ≤ `max_jump_up` | Jump up onto it |
| Short crate ahead (mountable) | Mount it (land on top) |
| Gap / hole ahead, solid ground beyond | Leap across to the far tile |
| On crate A, gap, crate B at same level | Leap across to crate B (does **not** drop into the gap) |
| Cliff down, nothing level across | Drop forward onto the lower tile |
| Wall taller than `max_jump_up` | In-place pop |
| No direction held | In-place pop |
| Standing on a crate, press toward a lower tile | Walk off / drop (normal movement, no jump) |

## Arc + segment behavior

- Y follows a parabola across the segment: `y(t) = lerp(y0, y1, t) + apex * 4 * t * (1 - t)`, peaking at `t = 0.5`.
- `apex` derived from the up-delta and the number of tiles spanned.
- During a jump: **no pushing**, **no terrain-riding** (Y comes from the arc).
- Initiate only from a settled tile, or buffer the press to fire when the current glide finishes.

## Validation / safety

- Validate the landing tile with the existing `is_tile_blocked`, plus a headroom check above the landing so the cat can't land inside geometry or under a low ceiling.
- `find_path` / A* stay tile-based and are unaffected; teaching the pathfinder to *use* jumps is a possible later enhancement.

## Parameters to expose (`@export`)

- `max_jump_up: float` — how high the cat can land onto (≈ 1.0–1.5 m).
- `max_jump_across: int` — gap reach in tiles; start at 1 (lands at dist 2).
- `jump_time: float` — arc duration.
- `jump_arc_base: float` — base apex height, plus distance/up-delta scaling.
- Interior **free mode**: separate and simple — `velocity.y = jump_speed` when grounded.

## Animation

Build feel first, art later.

- **Tier 0 (no Blender work):** procedural squash-and-stretch — scale model Y up at takeoff, squash on land, via a tween. Convincing cartoon hop at zero art cost. Use this to prototype.
- **Tier 1:** a single `Jump` clip, played once on jump start.
- **Tier 2:** split phases — anticipation/crouch → airborne (hold or loop) → land/recover — triggered like the existing `walk_loop` / rest-pose switching.

Notes:

- The **same airborne clip works for all jump types** (mount, gap, drop). Only the arc differs, and the arc is code. A dedicated "scramble onto ledge" clip is pure polish.
- Watch **phase-sync:** make `jump_time` match the clip's airborne length, or split into phases. Avoid stretching a single clip via `speed_scale` — the anticipation looks rubbery.

### Exporting animations from Blender (glTF)

Godot imports glTF animations as one clip per Blender **Action**, but only if staged correctly (otherwise only the active action exports). Reliable workflow:

1. In the Action Editor, create the new action (e.g. `Jump`), keyframe the hop **in place**.
2. In the **NLA Editor**, **Push Down** each action so each becomes its own NLA track/strip (`Walk`, `Jump`, …).
3. Export → glTF 2.0, enable animation export, turn on **"Group by NLA Track."** Each track exports as a named clip.
4. The strip/track **name becomes the clip name** in Godot — name them deliberately (the player code finds clips by name).

Gotchas:

- **No root motion.** Animate the bones but keep the armature/root at origin — code drives world position from the arc, so root translation in the clip would fight it.
- **Loop mode:** set per-clip in Godot's Advanced Import Settings after export (airborne = loop, jump = once), or set it at runtime as the walk clip already does.
- After re-exporting over `models/cat.glb`, Godot reimports automatically and new clips appear in `get_animation_list()`; the existing `_setup_animation()` discovery already handles finding them.

## Deferred / open questions

- **Hold-to-vault** control.
- **Walk-off feel:** smooth step-down vs a deliberate hop-off above some height threshold.
- **Longer leaps** (extend the dist-2 scan to dist 3+).
- **Pathfinder awareness** of jumps.

## Suggested build order

1. **Prototype:** tap jump + target resolution + arc + Tier-0 squash/stretch. Tap-only, mount by default, in-place pop on dead input.
2. **Support height** for blocks (mount/dismount).
3. **Blender jump clip** authored and wired in.
4. **Polish:** hold-to-vault, walk-off feel, interior free-mode jump.
