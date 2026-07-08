# Gameplay Design — Daily Tasks, Puzzles, Objects & States

Gameplay-first pass. What the player *does* each day, budgeted to **10–20 minutes**, with
the story woven on top (one line per task). Nameless roles throughout. Cross-refs:
`quest_web.md` (the web), `../story/arc.md` (the arc).

## Design targets

- **10–20 min/day.** A day = **1 main multi-step puzzle** (~5–8 min) + **2–3 small tasks /
  deliveries** (~2–3 min each) + **traversal** across town (~3–5 min) + **talking**
  (~2–3 min). Optional side tasks pad the upper end for thorough players.
- **One new idea per day**, reusing prior verbs so difficulty compounds gently.
- **Every day ends on a persistent change** (hybrid save) so tomorrow's town is different.
- **No fail states.** Puzzles can't soft-lock (props are recoverable / reset each loop);
  the only "clock" is the friend's soft decline (dialogue/behaviour, never game-over).

## The verb toolbox

### Already in the engine (reuse first)
- **Grid move** (click-to-move + WASD), isometric, terrain-following.
- **Push crates** one tile at a time; **crate onto a goal pad** triggers it.
- **Roll/shove balls**; **ball onto a goal pad** triggers it; balls roll with slope.
- **Jump** (tap): hop up a ledge, across a hole, **mount a crate top**.
- **Holes** (jump over), **water** (cat can't enter; **crates float** → platforms/bridges;
  crates **stack** in water).
- **Talk / interact** (face + I), **hints**, NPCs (still + roaming), **day/night phases**,
  keyhole see-through, goal-pad state (triggered/untriggered).

### To build (new systems, in rough priority)
1. **Carry & deliver** — hold one object (fish, oil, lens, board, letter). State on the
   player: `carried`. Verbs: pick up (I on a source), drop, **give** (I on a target). The
   cat visibly holds it; can't push/jump while carrying (or drops it). *This unlocks the
   most quests and is the #1 build.*
2. **Pressure plates + gates** — generalize the goal pad into a **plate** that holds a
   **gate/door open only while weighted** (by a crate, a ball, or the cat standing on it).
   Puzzle grammar: hold the plate to pass, or weigh it with a crate to pass yourself.
3. **Keys / locks** — a held key opens a specific gate (tower door). Persistent flag.
4. **Rat** — a small critter (nav + flee-from-cat). **Catch** by luring into a **baited
   trap** or cornering it. Per-loop entity; sealing the source removes it for good.
5. **Trap** — placeable object; **bait with fish**; rat enters → caught. Return to collect.
6. **Lever / crank** — a "use" interactable that toggles a mechanism (a sea-gate, the
   beacon's lens hoist, a winch). Holds state for the puzzle; some persist.
7. **Tree-with-item** — a high object dislodged by **stack-crates + jump** (bump it loose)
   or a thrown/rolled ball. Yields a carry item.
8. **Heavy object** — a sunk skiff / debris that needs a **lever + crates** (multi-tile,
   multi-step) rather than a single push. For the berth.
9. **Persistent-repair visual swap** — broken↔fixed mesh keyed to a flag (jammed slip →
   clear, gap → plank bridge, dark tower → lit), so the town visibly heals.

## Reusable puzzle templates

| Template | Verbs | Example use |
|---|---|---|
| **Crate bridge** | push, (float) | span a cliff gap / water to reach the tower path |
| **Crate stack + jump** | push, jump | reach a ledge or knock an item from a tree |
| **Plate & gate** | push/stand | weigh a plate with a crate to hold a gate; pass |
| **Ball run** | shove, slope | roll a ball down to a target / to knock something loose |
| **Carry & deliver** | pick/give | fish → friend; oil → tower; board → the hole |
| **Lure & trap** | carry(bait), herd | bait a trap, drive the rat in |
| **Contraption** | carry+use+plate | relight: oil + lens + crank + flame, in sequence |
| **Timed by phase** | move | a path only open at a certain time of day (tide/light) |

## Objects & game-state catalog

**Player inventory (runtime):** `carried` (one item id or none), key flags
(`has_tower_key`).

**Per-loop state (reset every dawn):** crate & ball positions, plate/gate states (unless a
day made them persistent), rat entities, placed traps, dropped carried items, NPC positions,
the fish you brought (ritual resets).

**Persistent flags (carry across loops — the town heals):**
`slip_cleared`, `crates_freed`, `bridge_permanent`, `lens_recovered`, `oil_secured`,
`has_rat_trap`, `rat_source_sealed`, `berth_cleared`, `keeper_trust`, `has_tower_key`,
`beacon_ready`, `beacon_lit`; plus knowledge flags (`learned_vet`, etc.).

**World objects:** crates, balls, goal pads/plates, gates/doors, keys, the trap, the rat(s),
the tree(+item), the sunk skiff, the sea-gate/winch, the beacon (oil tank, lens mount, crank,
flame), the friend's food bowl, delivery crates.

## Day-by-day gameplay (each ~10–20 min)

Format: **tasks** (gameplay) → *story weave*. New mechanic in **bold**.

### Day 1 — establishing (~10–13 min)
- **Move tutorial:** leave home, cross the town (traversal teaches click-move + camera).
- **Talk** to ~5 townsfolk in their districts (interact tutorial; fills time; seeds).
- **Push tutorial:** shove the marina hand's loose crate onto its spot (one easy push).
- **Carry & deliver tutorial:** take a wrapped fish from the fish seller **(carry)** home,
  **give** it to the friend (they eat it — today).
- **Notice, don't solve:** the dark tower (blocked path), a delivery stuck high, a rat at
  the market. Return home → sleep → wake to the same dawn.
- *Weave: a warm town that can't help; the loop lands via small things reset at dawn.*
- Persists: memory only.

### Day 2 — searching / first fix (~13–16 min)
- **Main puzzle — the jammed slip:** reposition 2–3 crates blocking the marina hand's slip
  (push puzzle; one crate must go on a **plate** to hold a boom-gate while you push the
  last one through). Solving frees the crates for later days.
- **Carry** fish to friend (eats less).
- **Traversal + jump intro:** climb the lower cliff path to the tower foot; a single **jump**
  up a ledge teaches the verb. Meet the keeper; glimpse the sick loved one; turned away.
- *Weave: the mirror appears; you don't yet know easing them = lighting the beacon.*
- Persists: `slip_cleared`, `crates_freed`.

### Day 3 — reaching (~16–19 min)
- **Main puzzle — cross to the tower path:** build a **crate bridge** across the cliff gap
  (push freed crates into the gap/water; they float), then **jump** the last span.
- **Sub-puzzle — the tree:** **stack crates + jump** to bump the beacon's **lens fitting**
  loose; **carry** it (stash at the tower foot).
- **Fetch:** the grocer's storm-stranded delivery on a ledge → return it → grocer gives
  **oil** + a **rat trap** (carry/inventory).
- *Weave: the ship carries a vet; the light is why it can't come.*
- Persists: `lens_recovered`, `oil_secured`, `has_rat_trap`, `learned_vet`.

### Day 4 — the rats (~13–16 min)
- **Main mechanic — lure & trap:** **bait the trap with fish**, **herd** a rat in, collect
  it; repeat for the fish seller, the mother, a retiree (three quick catches in different
  yards — a light timing/positioning puzzle each). They **come back next loop** (symptom).
- **Carry** fish to friend (leaves half).
- *Weave: the two-caretaker mirror (you ↔ the keeper) deepening; the mother a lighter echo,
  waiting on someone the sea keeps away.*
- Persists: knowledge (where they nest) — no permanent fix yet.

### Day 5 — the clever seal (~16–19 min)
- **Main puzzle — seal the source:** reach the **rat-hole behind the wharf** (via the
  bridge), **carry** a board to it, then **weigh it shut with a crate on a plate** so it
  holds. One fix, four yards go quiet.
- **Carry** good fish to the keeper's loved one; **trap** the rat by their bed.
- *Weave: kindness = repair, literalized; the keeper's thaw begins; the good-fish-refused
  gut punch.*
- Persists: `rat_source_sealed`, `keeper_trust`.

### Day 6 — the berth (~16–19 min)
- **Main puzzle — clear the berth:** a **heavy** sunk skiff/debris in the big dock. **Crank
  a winch (lever)** to raise it partway, wedge **crates** under it on **plates** to hold it,
  then push it clear — a 3-step contraption. Opens the berth.
- **Carry** fish to friend.
- *Weave: the town turning outward; the dock master's register line becomes fillable.*
- Persists: `berth_cleared`.

### Day 7 — the beacon (~18–22 min; the big one)
- **Gate — the key:** comfort the keeper's sick partner (fish + trap + **curl up beside
  them**) to be let deeper into the cottage, where you **find** the keeper's abandoned
  **tower key** (not given) → the **locked tower door** opens.
- **Main puzzle — assemble the light:** **carry oil** up the now-**permanent bridge/stairs**
  and fill the tank (**use**); **carry the lens** up and seat it (**use**); **crank** the
  hoist to raise the lens into the lamp; set a **plate**-held vent. Everything but the flame.
- *Weave: the keeper voices your own despair — "it won't bring anything in."*
- Persists: `bridge_permanent`, `beacon_ready`, `has_tower_key`.

### Day 8 — the turn (~10–12 min; short, weighty)
- **Fetch + use:** gather flint/kindling (one carry), climb, **strike the flame** (a single,
  deliberate use). The beam sweeps out. The keeper chooses it beside you.
- *Weave: to light it you both choose to hope — to let tomorrow come.*
- Persists: `beacon_lit`; the loop's grip loosening.

### Day 9 — the ship (~8–10 min; resolution)
- **Minimal gameplay:** walk to the dock as dawn comes different; the fog parts; the horn;
  the ship takes the cleared berth. Walk the vet to the friend. Reach them in time.
- *Weave: release, earned — you broke the loop when staying had become the danger.*
- Persists: run complete.

## Mechanic teaching curve

move → interact → push → carry/deliver *(Day 1)* → plate/gate + jump-up *(Day 2)* →
crate-bridge + stack-jump *(Day 3)* → lure/trap *(Day 4)* → carry+plate combo *(Day 5)* →
winch/heavy + plates *(Day 6)* → full contraption *(Day 7)* → capstone use *(Day 8)*.
Each day introduces exactly one verb and reuses all prior ones.

## Engineering to-build (mapped to what exists)

- **Carry/deliver** — new: a `carried` slot on the player + pickup/drop/give interactions;
  reuse the Interactable targeting for "give." Highest-value, unlocks the most.
- **Plate & gate** — extend the existing goal-pad code (it already detects a crate/ball on a
  tile) into a "held-while-weighted" plate that drives a gate node's open state.
- **Rat + trap** — new small nav critter + a placeable baited trap; per-loop, cleared on
  `rat_source_sealed`.
- **Lever/crank + winch + heavy object** — a `use` interactable toggling a mechanism; the
  heavy object as a multi-push/lever-gated mover.
- **Tree-with-item** — reuse stack+jump; add a "bump loose → spawn carry item" trigger.
- **Persistent-repair swaps** — broken↔fixed meshes toggled by flags in `World._ready`
  (extends the hybrid-persistence idea already in `GameState`).
- **Key/lock** — a held-key flag gating a door node.

## Open questions

- **Carry model:** one item at a time (recommended, keeps it puzzle-clean) vs. a small
  inventory?
- **Day length pacing:** is ~15 min the target average, with Days 7 longer and 8–9 shorter?
- **Optional side tasks** (extra rats, retiree favors) — count toward nothing mechanically,
  or grant small persistent shortcuts that shave time on later loops?
- **Rat catching feel:** lure-into-trap (calmer, puzzle-y) vs. active chase/corner (twitchy)?
- **Phase-timed puzzles:** do we want at least one "only at low tide / only in daylight"
  gate, using the day/night system as a mechanic?
