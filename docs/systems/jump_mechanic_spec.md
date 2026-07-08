# Jump Mechanic — Design Spec

Status: **Tier 0 implemented** — tap-to-jump, crate mounting, walk-off hop, and a
cooldown are built and working. Animation is still procedural squash/stretch
(no Blender clips yet). Interior free-movement mode jumping is not done.

Touched files: `scripts/player.gd`, `scripts/world.gd`, `project.godot` (the
`jump` input action on Space).

Scope: grid (isometric) movement. Interior free-movement mode is handled separately.

## Intent

Add a jump to the cat, triggered by the **space bar**, that feels intuitive and stays true to the game's deterministic, tile-based puzzle movement. The cat always lands on a whole tile — no mid-tile or on-edge landings — so existing systems (`can_enter`, `is_tile_blocked`, `find_path`) keep working.

## Core principle

A jump is **not** a free physics arc. It's a special movement segment that targets a tile, with a **parabolic Y arc** instead of terrain-riding. Because the target is always a tile, the grid invariants are preserved.

This collapses "vertical jumps of different heights" and "horizontal jumps" into one thing: **pick the target tile, derive the arc.** The arc's apex is computed from the up-delta and the horizontal distance; heights are never hand-authored.

## The two verbs (key mental model)

The player learns one simple distinction:

- **Walk** off an edge → you step or hop *down*. This is how you descend on purpose.
- **Jump (Space)** → you *traverse*: reach across to a foothold, preferring a landing at (or up to) your current level, and only fall if there's no such foothold ahead.

And the push-vs-mount distinction follows from the same idea: **walking into a crate pushes it; pressing Space mounts it.** Pushing never involves Space, mounting always does, so the two can't be confused.

## Input (as built)

- **Key:** Space bar (the `jump` action in `project.godot`).
- **Tap only.** Hold-to-vault is a deferred, principled future addition (see Mount vs Vault).
- **Direction:** the currently held movement direction (camera-relative, like walking). If none is held, the cat auto-mounts a crate it's *facing*, otherwise pops in place.
- Works **standing or mid-glide**. A jump pressed while walking takes off from where the cat currently is.
- **Cooldown:** after a jump lands, another can't start for `jump_cooldown` seconds.
- Jump is ignored while actively **pushing** a crate (so the crate can't be left half-slid).

## Target resolution rule (as built)

The jump plans from `base` = the tile the cat is physically over right now (`_world_to_tile(global_position)`), so a jump while gliding still lands one tile from the cat, not two.

With a direction held, scan in priority order:

1. **Land ahead (dist 1).** If the tile directly ahead is level or up within `max_jump_up` → land there. Covers: flat hop forward, step up a ledge, **mount a crate** (lands on the crate top).
2. **Leap across (dist 2).** If the tile directly ahead is a *drop*, peek one tile further. If it has a level-or-up foothold → leap across to it. Covers crate → gap → crate.
3. **Drop forward (dist 1).** If nothing level-or-up is reachable across, drop forward onto the nearer lower tile.
4. **Pop in place.** A solid wall / off-board ahead, or dead input → the cat hops in place and stays put. (Walls are **not** vaulted.)

With **no direction held**: if the cat faces a mountable crate, it auto-mounts it; otherwise it pops in place.

The preference is **height-aware**: footholds at or above the current level beat falling. That's what makes the crate-to-crate-across-a-gap leap work instead of dropping into the gap.

## Support height (implemented)

Walking uses terrain only (`get_elevation`). Jumps use a separate **surface** that includes a crate sitting on a tile, so the cat lands on the crate top rather than the terrain beneath it.

- `world.gd: surface_elevation(x, z)` → terrain elevation, plus the crate height if a crate is on that tile. Wired to the player as `surface_provider`.
- `world.gd: has_block(tile)` → is there a mountable crate here. Wired as `block_provider`.
- `world.gd: _is_pushable_tile(tile)` (block **or** resting ball) → wired as `occupied_provider`. The player treats a tile with a ball (occupied but no block) as **not landable**.
- Crate height is measured from the crate mesh AABB (`_block_height`).
- Getting **off** a crate: just walk off the edge — support reverts to terrain and the cat hops/eases down. No second jump press needed.

## Mount vs vault

For a short obstacle (e.g. a crate) a jump toward it has two possible endings:

- **Mount** — end up standing *on top of* the crate. **Implemented; the default.**
- **Vault** — clear *over* it and land on the far tile. **Deferred.**

A wall taller than `max_jump_up` can be neither mounted nor cleared → pop in place.

Levers:

- Whether a crate is mountable is decided by `max_jump_up` vs the crate height (currently `max_jump_up = 2.0`).
- **Hold-to-vault** is the natural future control: the crate case is the one genuine ambiguity (two valid landings in the same direction), so reserving the hold gesture for it is principled. Not built yet.

## Case table (direction held unless noted)

| Situation | Result |
|---|---|
| Flat ground ahead | Hop one tile forward |
| Ledge up, ≤ `max_jump_up` | Jump up onto it |
| Crate ahead (within `max_jump_up`) | Mount it (land on top) |
| Facing a crate, **no direction held** | Auto-mount it |
| Gap / drop ahead, level ground beyond | Leap across to the far tile |
| On crate A, gap, crate B at same level | Leap across to crate B (does **not** drop into the gap) |
| Cliff down, nothing level across | Drop forward onto the lower tile |
| Ball ahead | Pop in place (balls aren't landable) |
| Wall taller than `max_jump_up`, or off-board | Pop in place (no vault) |
| Dead input (no direction, nothing to mount) | Pop in place |
| **Walking** off a ledge/crate ≥ `hop_off_min_height` | Gentle hop-off (small arc), not a ramp |
| **Walking** off a step < `hop_off_min_height` | Smooth ramp down (no hop) |

## Arc + segment behavior (as built)

- Y follows a parabola: `y(t) = lerp(y0, y1, t) + apex * 4 * t * (1 - t)`, peaking at `t = 0.5`. X/Z ease linearly over `jump_time`.
- `apex = jump_arc_base + max(0, up) * 0.5 + max(0, span - 1) * 0.3`. Walk-off hops override this with the small fixed `hop_off_arc`.
- During a jump: **no pushing**, **no terrain-riding** (Y comes from the arc).
- A walk-off hop is started from inside `_begin_segment`; it preserves any click-to-move path so the cat keeps following it after landing.

## Validation / safety

- Landing tiles are validated with the existing `is_tile_blocked` (crates are exempt — they're landable on top; balls are excluded).
- No explicit overhead/ceiling **headroom** check yet — fine on open terrain, worth adding before interiors or overhangs.
- `find_path` / A* stay tile-based and are unaffected; teaching the pathfinder to *use* jumps is a possible later enhancement.

## Parameters (`@export` on the player, as built)

- `max_jump_up: float = 2.0` — max height the cat can land up onto (taller = wall → pop).
- `jump_time: float = 0.32` — arc duration, independent of distance.
- `jump_arc_base: float = 0.45` — base apex; grows with up-delta and span.
- `hop_off_min_height: float = 0.5` — min drop for a *walk-off* to become a hop.
- `hop_off_arc: float = 0.18` — small apex for a walk-off hop (so it's a hop, not a jump-up).
- `jump_cooldown: float = 0.2` — lockout after landing.
- Interior **free mode**: not yet — would be a simple `velocity.y = jump_speed` when grounded.

## Animation

Build feel first, art later.

- **Tier 0 (done, no Blender work):** procedural squash-and-stretch — stretch on takeoff, squash on land, via tweens on the model scale. Convincing cartoon hop at zero art cost.
- **Tier 1 (todo):** a single `Jump` clip, played once on jump start.
- **Tier 2 (todo):** split phases — anticipation/crouch → airborne (hold or loop) → land/recover — triggered like the existing `walk_loop` / rest-pose switching.

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

## Known rough edges / deferred

- **Walk-off body pitch:** when walking off a crate the body doesn't visibly pitch for the drop (it reads terrain slope, not crate height). Cosmetic.
- **Hold-to-vault** control (clear over a crate instead of mounting).
- **Headroom check** before interiors/overhangs.
- **Longer leaps** (extend the dist-2 scan to dist 3+).
- **Pathfinder awareness** of jumps.
- **Interior free-mode jump** (`velocity.y` impulse when grounded).
- **Animation Tiers 1–2** (authored Blender jump clip).

## Build order

1. ✅ **Prototype:** tap jump + target resolution + arc + Tier-0 squash/stretch.
2. ✅ **Support height** for blocks (mount; dismount by walking off).
3. ✅ **Feel pass:** jump-while-moving, walk-off hop, cooldown, one-tile fix.
4. ⬜ **Blender jump clip** authored and wired in.
5. ⬜ **Polish:** hold-to-vault, walk-off body pitch, headroom check, interior free-mode jump.
