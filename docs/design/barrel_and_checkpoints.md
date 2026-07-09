# Barrel, Checkpoints & the Buoy — Design Spec

Gameplay spec for the **barrel** (a heavy, directional roller), the **checkpoint**
safety net that makes its irreversible commits fair, and the **buoy** that replaces the
placeholder ball. Written to be implementable on top of the existing crate-push
(`world.can_enter` / `player._begin_segment`), ball-roll (`world._roll_ball`), and goal-pad
systems. Nameless roles.

## 0. Implementation status (current)

Built so far: an upright barrel that **blocks** and can't be slid; a **1-second push
wind-up** then a **topple** one tile in the pushed direction; the resulting **lying**
barrel rolls **one tile at a time, perpendicular to the tip direction** (see §2), like a
log; a barrel tipped/rolled **into water floats and bobs**; and the cat can **jump onto a
lying barrel and stand on it**, then **ride it** — walking along its roll axis rolls the
barrel a tile with the cat on top (at push pace), on land or water, except a **floating
barrel can't be rolled out of the water**. Not built yet: slope **momentum**, pressure
**plates**, **checkpoints**, chain knock-overs, pit-loss, and breakage.

## 1. The barrel — concept

A barrel is **too heavy to slide**. You can't push it along like a crate. What you *can* do
is **knock it over** — and the direction it falls decides the one axis it can then roll on,
forever (the cat can't stand it back up). So a barrel is a **commitment**: choose the tip
direction well, or you're stuck (that's what checkpoints are for). In the fiction it's a
lamp-oil / salt barrel, hoarded on the wharf since nothing ships out.

## 2. States & rules

### Upright (on its end)
- Occupies one tile; **blocks** movement; **cannot be pushed** (too heavy to slide).
- **Knock-over (tip):** the cat walks into it from a cardinal direction `D`.
  - Let the barrel be on tile `B`, cat on `B - D`. The barrel tips into `L = B + D`.
  - Requires `L` in-bounds and clear (walkable ground **or** water — see Water). If `L` is a
    wall / crate / another barrel, the tip is refused (nothing happens; the cat just stops).
  - Result: barrel moves to `L` and lies down **pointing along `D`** (its length is on the
    `D` line). Because a cylinder rolls *across* its length, it can now be rolled **only
    perpendicular to `D`** — never further along `D`. The cat steps into the vacated tile
    `B` (it reads as a shove).
- Upright barrels can be **rolled into by another rolling barrel** and knocked over in the
  travel direction *(optional/advanced chain — cut for v1)*.

### Lying (on its side)
- Occupies one tile; lies **pointing along the tip direction `D`**, which gives it a fixed
  **roll line perpendicular to `D`** (tipped N/S → rolls E/W, and vice-versa).
- **Roll:** the cat pushes it from a tile on its roll line → it rolls **one tile** that way,
  like a log; the cat follows into the vacated tile (exactly like a crate push, but
  constrained to that one perpendicular axis).
- **A push along its length (parallel to `D`) does nothing** — go round and push from the
  perpendicular side.
- **Cannot be stood back up** by the cat. This is the irreversible part.
- **Momentum:** if a roll (or a tip) puts the barrel onto a **downhill** tile along its
  axis, it keeps rolling on its own — reuse the ball's constant-decel roll
  (`_roll_ball`/`_launch_ball`) — until it hits an obstacle, reaches flat ground, or enters
  water/a gap. Uphill must be pushed and may stall.

### Interactions
- **Water:** a barrel tipped or rolled into water **floats** (stays lying, orientation
  kept) and bobs on the surface, and it's a **standable platform** — the cat can jump on and
  **ride it across the water** along its roll axis (a **floating bridge / stepping line**).
  It **can't be rolled back out onto land**, though: once wet it stays wet.
- **Gap / hole:** **crates** are the gap-fillers — push a crate into a hole to make a step
  or bridge. A **barrel** that rolls into a pit is simply **lost** (can't be retrieved) →
  reset to the last checkpoint. Keep barrels clear of open holes unless you mean it.
- **Pressure plate:** a barrel on a plate is **heavy → holds it** (upright or lying). Since
  upright can't be slid onto a plate, you **tip/roll** it on — a natural use of the verb.
- **Slope run (the signature move):** tip a barrel at the top of a ramp so it rolls down its
  axis and **strikes something** at the bottom (loosens debris, drops into the berth, thumps
  a plate). Requires tipping in the correct downhill direction.
- **Oil barrels (skin):** clearly lamp-oil, so they read as tied to the beacon. Once
  positioned at the tower foot, **tap** it (a `use`) to fill a carryable **oil can**.
  *(Optional: a barrel that rolls too hard into a wall bursts and spills — reserve only for
  an intended "grease the slipway / soak a wick" beat, else disable breakage.)*

## 3. Puzzle grammar (what the barrel makes possible)

- **Directional Sokoban.** A barrel only moves in straight lines and can't turn or
  re-stand, so the puzzle is: **the tip commits the barrel to one roll line (the axis
  perpendicular to the tip), then you roll it in a straight line until a wall/stopper halts
  it on the exact target tile.** Tipping is how you *choose which axis* a barrel travels on;
  travel then runs across that tip. Place stoppers and walls to shape the solution. Corners
  are "solved" by using multiple barrels or terrain, not by turning one barrel.
- **Commit-and-consequence.** A wrong tip strands the barrel on the wrong axis. The
  checkpoint (below) is the intended undo, so misjudging is a *lesson*, not a dead run.
- **Ramp strike.** Tip → momentum roll → impact. Reads great and teaches slope + direction.
- **Buoyancy / tide combo.** Roll a barrel into the water at **low tide** so it lodges;
  on the **evening high tide** it floats up and lifts a net/boom (buoyancy) — phase-timed,
  signposted (see `objects_and_kinetics.md`).
- **Weigh a plate** you can't reach any other way (too heavy to carry, so it must arrive by
  tip/roll).

### Example puzzle (illustrative)
The berth is fouled by debris in a slot two tiles below the wharf ramp. An oil barrel stands
at the ramp top.
1. Tip it **down the ramp** (correct axis) → it momentum-rolls to the ramp foot and stops
   against the rail.
2. Roll it one tile onto the **plate** that holds a boom-gate open.
3. Cross the boom; **winch** the debris; the slot clears.
Tip it the *wrong* way at step 1 (say, sideways off the ramp into the sea) → it floats
uselessly out of reach → **reset to the last checkpoint** and retry.

## 4. Checkpoints (the safety net)

Irreversible commits (a mis-tipped barrel, a barrel lost down a pit) must never force a full
restart, so there's a **"Reset to last checkpoint"** that undoes the current attempt without
ending the day.

Exact checkpoint rules are **TBD** (how often they're set, where they land you). All this
spec assumes is: the player can always fall back to a recent checkpoint if a puzzle becomes
unsolvable. Sleeping remains the coarse reset (ends the whole day, advances the loop).

## 5. The buoy — replacing the placeholder ball

Where the barrel is heavy and directional, the **buoy** is its opposite: a **light,
omni-directional roller**. It's a cork mooring buoy, pulled off the moorings since no ship
ties up.

- **Roll:** pushes/rolls **any** cardinal direction (like the old ball); light, so it moves
  easily and can be nudged around corners over successive pushes.
- **Momentum on slopes** like the ball (reuse `_roll_ball`).
- **Floats** — its home element; a line of buoys = quick **stepping floats** across a
  channel.
- **Too light to hold a plate** — deliberate contrast with the barrel (weight puzzles need a
  barrel/crate; float/agility puzzles want a buoy).
- **Not carryable** (too big for the mouth) — it's a roll-only object.

Buoy vs. barrel is the core kinetic contrast: **agility & flotation (buoy)** vs. **weight &
committed direction (barrel)**. Many puzzles ask which tool the situation needs.

## 6. Engine mapping

- **Buoy** ≈ the current **ball**: reuse ball roll/momentum/goal wholesale; just skin it,
  mark it "floats," and set "doesn't weigh plates."
- **Barrel** = new object combining:
  - a **tip** action (new): on a push into an *upright* barrel, run tip logic (validate `L`,
    move barrel, set `lying` + axis, advance cat) instead of a slide.
  - **axis-locked roll** (extend crate push): a *lying* barrel accepts a push only across
    its length (perpendicular to the tip direction); on a downhill next tile, hand off to
    the **ball roll** for momentum.
  - **float / gap / plate** hooks reuse existing water-float, hole, and goal-pad code.
- **Plates & gates** = extend the goal pad into "held while weighted" driving a gate node
  (already sketched in `gameplay.md`).
- **Checkpoints** = a snapshot/restore of the movable-object + player + per-phase-objective
  state, taken on each `DayNightCycle` phase change; restore on request. `GameState`
  (persistent flags) is untouched except for reverting flags set during the current phase.

## 7. Open questions

- ~~Tip geometry~~ **RESOLVED:** falls forward one tile; cat steps into the vacated tile.
- ~~Floating-barrel rolling~~ **BUILT:** the cat mounts a floating barrel and rides it
  across the water along its roll axis (float-bridges). The one rule added in practice: a
  floating barrel **can't roll out onto land**. Crates, not barrels, still fill gaps.
- **Checkpoints:** exact rules TBD by you — this spec only assumes a "Reset to last
  checkpoint" exists.
- **Chain knock-over** (a rolling barrel tips an upright one): fun but adds edge cases —
  v2, or never?
- **Barrel breakage/spill:** off by default, or wanted as a specific puzzle (grease a
  slipway, soak a wick)?
- **Standing a barrel up:** always impossible (assumed), or possible via a special spot
  (a cradle / two cats / a tipping frame) as a late mechanic?
