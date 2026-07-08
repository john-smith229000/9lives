# Gaps, Loose Ends & Unspecced Systems

An honest production-readiness pass: what the docs assume that **doesn't exist yet** or isn't
pinned down. The story/design layers are solid; most gaps are (1) new systems the puzzles
need, (2) architecture decisions, and (3) a handful of story locks. Priorities: **P1** blocks
the vertical slice / core loop, **P2** needed for the full arc, **P3** polish/production.

## 1. Systems the design needs but the code doesn't have yet

| System | Status | Needed for | Priority |
|---|---|---|---|
| **Carry-in-mouth** (pick up / drop / **give**; one item; blocks jump while held; visual) | **slice version BUILT** (`player.gd` give/take/is_carrying + carry_offset; `interaction.gd` `on_cat_interact` hook; the fish handoff via `fish_source.gd` + `friend_cat.on_cat_interact`) | fish, rat, lens, oil can, key, gift | ~done (P1) |
| **Pressure plates + gates/booms** (hold-while-weighted → open a gate node) | concept only (extend goal pad) | the slip (D2), the seal (D5), the berth (D6), the beacon vent (D7) | **P1** |
| **The barrel** | **specced** (`barrel_and_checkpoints.md`) | D6, D7 | ok |
| **The buoy** | described (extend ball) — thin, but low-risk | optional puzzles | P2 |
| **Rat + baited trap** (a flee-AI critter; catch; carry it; respawn until source sealed) | designed, **no build spec** | D4–D5 | **P1** |
| **Mechanisms** (lever/crank, **winch/capstan**, **derrick + cargo net**, sea-gate) | described, **no spec** | the berth (D6), the beacon hoist (D7) | P1/P2 |
| **Heavy mover** (the sunk skiff: multi-step winch+wedge+push) | described, **no spec** | D6 | P2 |
| **Tide as a global, phase-driven state** (water height + which tiles are walkable/blocked change by phase) | **not built**; day/night phases exist but tide isn't wired | every low/high-tide gate (D3–D6) | **P1** |
| **Keys / locks** (a held key opens a specific door) | mentioned, no spec | the tower (D7) | P2 |
| **Friend "leak" state** (per-loop decline level → pose/anim/dialogue: eats less → ear down → barely stirs) | premise locked, **no data model**; `friend_cat.gd` only lay/stand | the whole emotional spine | **P1** |
| **The gift ritual** ("something to look at" → a give + an accumulating shelf that resets per loop) | designed, no spec | D1→D9 payoff | P2 |
| **Checkpoints** | intentionally **TBD by you** | quality-of-life for barrel commits | P2 |

## 2. Architecture decisions not yet made  *(pin these before building Days 2+)*

- **One town, reloaded per day — how is per-day content configured?** The slice reloads
  scene 6 on sleep and reads `GameState.current_day`. But there's **no system that turns
  `current_day` into "these props / these NPC positions / these objectives / this flow."**
  Options: a per-day data resource (recommended), or a `scene6_flow` that branches on the
  day, or one flow script per day. **This is the biggest unbuilt piece for the full arc.**
- **Applying persistence on load.** `GameState` holds flags, but nothing **reads them on
  `_ready` to rebuild the world** — the healed states (`slip_cleared`, `bridge_permanent`,
  `berth_cleared`, `beacon_lit`, refilled shelves, etc.) need a pass that swaps meshes /
  skips completed daily setups / restores unlocked access. Designed in `town_structures.md`
  §4 as "swappable variants"; **not specced or wired.**
- **Save to disk (cross-session).** `GameState` is an **in-memory autoload** — a run's
  progress is lost on quit. A 9-day game needs a **save file** (write flags + `current_day`;
  load on launch; New Game resets). Not present.
- **Interiors at scale.** `house_controller.gd` handles **one** house. The game needs
  **several enterable buildings** (home, café, grocer, dock office, foot cottage) + the
  **two-space lighthouse** (a *vertical* tower interior). Needs: multiple controllers, and
  **carry working across the interior/exterior threshold** (does the held item persist
  through the fade + mode swap? untested).

## 3. UX / UI not specced

- **Objective display.** Every day's "Objective (told plainly)" assumes the player can *see*
  the current task. Today there's only the **Dialogue box + a transient hint banner** — no
  persistent objective/journal. Decide: lean on the hint banner, or add a small objective HUD.
- **Control tutorialization.** Day 1 teaches move/talk/carry *implicitly*; there's no prompt
  system for new verbs (carry, jump, the desk-jump, tip-a-barrel). At least first-use prompts.
- **Time-of-day / day-count readout.** The phase drives gates and pacing — does the player
  see the time of day and which loop they're on? Not specced.
- **Wayfinding.** The town is a 100×100 map; finding the right character/district may need a
  cue (a soft marker, a chime, the highlight system extended). Undecided.

## 4. Day-9 / cinematic staging  *(P2)*

The finale is scripted, not a puzzle, and has **no staging spec**: the **ship** (model +
approach/docking), the **vet** NPC (arrival + pathing to home and the cottage), the mother's
**returned** figure, and how the "healed town" reveal is framed. Needs a short sequence spec
(likely a `SceneFlow`-style screenplay + a couple of set-piece nodes).

## 5. Story loose ends / decisions to lock

- **Names** — town, the two cats, and every role (all still placeholder).
- **Setting species** — cozy animal town assumed; not confirmed. (Affects models/art.)
- **The two cats' shared history** — came together / one took the other in.
- **Ending tone** — recovery ambiguity + does the cat ever understand the loop
  (recommended: soft-yes / never — not locked). See `story/day9.md`.
- **The keeper's partner** — relationship (spouse / companion / sibling) + the sailor detail
  (for the boat plant). **Why the keeper stopped** flavor (despair + sole care is set; grief
  vs. their own frailty is open).
- **What the illness is** — deliberately vague is fine, but the vet "curing" it implies
  something treatable; confirm we keep it unnamed.
- **Harbor obstruction** — berth-only, or **also a sea-gate at the mouth** (a second "let the
  ship in" fix)? Affects the D6/late map and pacing.
- ~~Communication model~~ **RESOLVED (canon in STORY.md):** cats never speak (only cat
  noises + body language); the player has inner monologue (the narration); non-cat townsfolk
  may speak; cat-to-cat beats and item exchanges are wordless. No cat dialogue, ever.

## 6. Content & production  *(P2–P3)*

- **Level blockout.** `town_structures.md` is art-direction, not a **map layout** — nobody's
  placed the districts/buildings/puzzle lanes on the scene-6 grid. Needs a blockout (which
  tiles are the wharf, square, cliff path, each door) — and remember barrels need clear
  straight runs + stopper walls.
- **Per-day puzzle layouts** — the specific tile coordinates for each day's props/plates/
  gates (the day docs describe them; none are placed).
- **Dialogue** — all lines are yours to write (docs are beats/intent only, per your call).
- **Audio** — the **horn's absence → horn** is a load-bearing motif; ambience, the two-lights,
  footsteps exist. Needs an audio pass; the horn especially.
- **Art** — the healed-state mesh variants, and models for barrel/buoy/rat/trap/winch/derrick/
  the ship/the vet.

## What's already solid (so this is balanced)
The nine-day arc + per-day beats; the character bible + the two-caretaker/three-hopes theme;
the quest web + the day-by-day **task ladder** (what each task pays); the **barrel/checkpoint**
spec; the object/kinetics kit; the interiors *concept*; the town-structures art-direction;
the throughlines/foreshadow ledger; and the built engine (grid move, push/jump, crates, balls,
water-float, goal pads, dialogue/interactables, characters, day/night, the scene-6 slice with
the fade + day-loop hooks).

## Suggested order to close the P1 gaps (builds on the slice)
1. **Carry-in-mouth** (unlocks the most).
2. **Plates + gates** (extend the goal pad).
3. **Tide as a global phase state** (unlocks the phase gates + reuses day/night).
4. **Rat + trap** (needs carry).
5. **Friend leak-state model** (data + `friend_cat` poses/anim hooks).
6. **Persistence-apply-on-load + save-to-disk** (so days actually accumulate).
7. **Per-day content config** (turn `current_day` into a day's setup + flow).
8. Then P2: mechanisms/heavy mover, keys, interiors-at-scale, objective UI, Day-9 sequence.

Nothing here contradicts the design — it's the "make it buildable" layer the story/design docs
sit on top of.
