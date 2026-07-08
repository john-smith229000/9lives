# Locations & Building Interiors

Which places you can enter, why, what's inside, and **how** entry works on top of the
existing interior system. Roles only, no dialogue. Cross-refs `../systems/…` (engine),
`gameplay.md`, `chain_quests.md`.

## The core principle: outdoors vs indoors

The two movement modes the engine already has map cleanly onto two kinds of space:

- **Outdoors = the grid.** Isometric, click-to-move, tile-locked. This is where all the
  **kinetic puzzles** live — barrels, crates, buoys, plates, the winch, tides. You can't
  bring a barrel through a door, and that's the point: the street is the puzzle board.
- **Indoors = free move.** WASD, physics, real walls (the engine's "free mode," entered via
  a doorway trigger — see `house_controller.gd`). Interiors are for **people, clues, items,
  and quiet** — talk, read, pick up, sit. No grid puzzles inside; the tension drops and the
  story breathes.

So a good day alternates: solve something on the grid outside → step indoors for a
conversation / a clue / an item → back out. Indoors is the exhale.

## How entry works (the existing mechanic)

From `house_controller.gd`: a thin **doorway trigger box** at the entrance. Walking across it
**fades to black**, swaps to the building's **interior camera**, and switches the cat to
**free mode** (colliding with hand-placed interior wall collision). Crossing it again
reverses. It's all one world — no separate scene load — the interior is a real room the
camera drops into.

**To make a building enterable, author (per building):**
1. A building model with a real **interior room** + hand-placed **wall collision**
   (`house1.glb` is the existing template to copy/extend).
2. An **`inside_view` camera** framing the room.
3. A **doorway trigger** box at the threshold.
4. A **HouseController** node wired to player + exterior camera + house + trigger.

Notes: the **keyhole see-through** already handles the *exterior* case (the cat showing
through a building's roof/walls when outside); indoors uses the interior camera so keyhole
isn't needed inside. The **carry-in-mouth** item works in free mode, so you can carry a fish
into the sickroom or a book to the counter. Grid props (barrels/crates) simply don't exist
indoors.

## Enterable buildings

### 1. Home — the cottage  *(the emotional anchor; enter every day)*
- **Why enter:** it's where you **wake** and **sleep beside the friend** — the loop's
  bookend. The friend lives here (move the friend indoors from the current greybox
  placement). Also the "bring me something to look at" gift and the daily fish delivery.
- **Interior:** one warm room — a blanket-nest by the window (the friend), a low table, a
  shelf for the gifts you bring (they accumulate within a day, reset on the loop). Small.
- **Interactions:** check on the friend; give the carried fish; place the day's gift on the
  shelf. All free-move, all quiet.
- **How it ties to the loop:** wake = fade **in** on the interior camera (reuse `ScreenFade`
  from the day-loop work); sleep = curl by the nest → fade **out** → reload. The doorway is
  how you leave into town each morning and return each night.
- **Days:** every day.

### 2. The café / bookshop  *(the clue hub)*
- **Why enter:** the town's memory. This is where you **read your way to understanding** —
  the lighthouse mechanism, the town's history, and (cross-referenced with the dock
  register) that the incoming ship carries the vet. The café keeper's loop-sense deepens
  here across days.
- **Interior:** shelves (books = examinable), a counter, two chairs with the ever-present
  two cups (one always cold), a **barometer stuck on CHANGE**. Cozy, dim, dusty gold light.
- **Interactions:** a **read** interaction on specific books/records that sets a knowledge
  flag (e.g., "the beacon needs oil + a lens + a clear stair," "ships used to read the
  light," later "the ship is a supply-and-medical run"). A light **find-the-right-shelf**
  browse rather than a puzzle. Sitting in the second chair = an optional quiet beat that
  advances the café keeper's uncanny-recognition thread.
- **Days:** 1 (mood), 3 (the vet clue crystallizes), and a recurring return as the
  investigation deepens.

### 3. The general store / grocer  *(items + a small interior fetch)*
- **Why enter:** to get the **rat trap** and **lamp oil** — but they're in the **back
  storeroom**, and the front is all half-empty shelves. Also where you hand over the
  storm-stranded delivery you recover outdoors (Day 3).
- **Interior:** a shop front (counter, sparse shelves) and a **back storeroom** — reachable
  only after you return the lost delivery (the grocer unlocks it / clears the doorway).
  Inside the storeroom: the oil (an outdoor **barrel** once it's rolled out; a carryable
  **can** for topping up), the trap, and — a small motivation — signs the rats have been in
  here too, tying to the rat quest.
- **Interactions:** give the recovered delivery at the counter; collect the trap + oil from
  the storeroom (pickup/carry). No grid puzzle inside — the "puzzle" (recovering the
  delivery from the tree/ledge) happens **outdoors**; indoors is the payoff.
- **Days:** 3 (get trap + oil), 4 (bait), 7 (oil for the beacon).

### 4. The lighthouse  *(two interiors; the endgame)*
The most important building, in **two connected interior spaces**:
- **4a. The foot cottage — the sickroom.** Where the **keeper** tends their **sick partner**,
  alone. Early days you're **kept at the doorway** (the partner needs quiet) — you see in but
  can't enter. As you comfort the partner (rat sealed, fish, curling up beside them) the
  doorway **opens to you**, and once inside you **find** the **tower key the keeper stopped
  wearing** (by the bed / on its old hook) — not given, found. A single bedside lamp is
  always lit — the keeper's "small light."
  - **Interactions:** deliver fish; place/collect the bedside rat trap; **curl up beside the
    partner** to comfort them (a quiet beat that builds `keeper_trust` — the cat's own kind
    of care); then pick up the found key.
- **4b. The tower — the climb + the lantern room.** A vertical interior: **stairs** up in
  free mode to the **lantern room** at the top, where the beacon lives. Locked until you
  hold the **tower key**.
  - **Interactions (Day 7 assembly, all free-move "use" actions, not grid):** fill the oil
    tank from carried cans; seat the carried **lens fitting**; **crank** the hoist to raise
    the lens; open the vent. Day 8: **strike the flame**. The window looks out over the
    fogged harbor — the view that pays off when the ship comes.
- **Why two spaces:** the cottage is the *why* (the sick partner), the tower is the *how*
  (the light); the keeper is caught between them, unable to leave one to climb the other.
- **Days:** glimpsed Day 1; cottage doorway Days 2–6 (trust building); tower Days 7–8.

### 5. The dock master's office  *(a tiny interior; the ship-seed)*
- **Why enter:** the **dock master** is *in here*, working at their desk by the dock, and the
  **harbor register** is open on it — the ship-seed (a vessel *listed and due*, blank line).
- **Staging (the cat beat):** the dock master is heads-down and won't look up, so the cat
  does the obvious cat thing — **jumps up onto the desk** (right onto the ledger) to get
  their attention. That's the interact: from the desk you read the register and get their
  grumbling attention. A small, characterful, un-narrated way to make "talk to the official"
  play like a cat.
- **Interior:** cramped — the desk + big stamped ledger, tide charts, a stopped clock. The
  desk-jump + ledger do the work.
- **Days:** 1–3 (the ship exists → *due* → cross-referenced with the café as the vet run);
  Day 6 the berth job (the desk is where his armor cracks). Day 9 the blank line finally gets
  a docked ship's name.

### 6. The marina worker's shed  *(optional, small)*
- **Why enter:** where the **winch/tools** and the **plank** for the permanent bridge come
  from; a place to find the marina worker in bad weather. Optional — could stay a
  lean-to/exterior workbench if we want to keep interiors focused.
- **Interior:** cluttered workshop — coiled rope, a workbench, the plank leaning ready.
- **Days:** 2 (meet), 6–7 (winch, plank).

## Exterior-only locations (stay on the grid)

Not everything should be enterable — the street *is* the puzzle space, and too many
interiors kill the rhythm.

- **The fish market** — an open **stall** under an awning (exterior), with a small adjacent
  **cold-store** you only peer into (the rats get at the catch there; the good fish waits
  there). Keep the seller and the trading outdoors.
- **The wharf / marina slips** — the crate/barrel/boom/winch puzzles; pure grid.
- **The square** — the retiree bench, the storm-stranded tree, the town's crossroads.
- **The cliff path** — the climb to the lighthouse; grid jumps + the box-bridge.
- **Most houses** — facades only; doors that don't open, so the few that *do* feel special.

## Camera & transition notes
- Each interior needs its own framed **`inside_view`** camera; consider a second angle for
  the tall tower (a low angle at the base, a higher one in the lantern room) if one feels
  cramped.
- The **fade** (`house_controller` uses its own black `ColorRect`) should share styling with
  the day-loop `ScreenFade` so all fades feel like one game.
- **Home** is the exception where the interior camera + fade also carry the wake/sleep loop
  beats — worth special-casing so waking *inside* reads as the day starting.

## Per-interior authoring checklist
For each enterable building: interior room mesh + wall collision; an `inside_view` camera; a
doorway trigger box; a `HouseController` wired to player/exterior-cam/house/trigger; any
Interactables (people, examinable objects, item pickups) placed inside; confirm carry works
across the threshold; confirm grid props can't follow you in.

## Open questions
- **Tower interior movement:** free-move stairs (fits the interior rule) vs. a bespoke
  grid/ladder climb — free-move is simpler and consistent; confirm it reads well vertically.
- **Marina shed:** real interior or exterior workbench? (Lean exterior unless it earns a room.)
- **How many interiors is too many?** Current enterable set: home, café, grocer, lighthouse
  (×2), dock office (+ maybe shed). That's a lot to build — is any cuttable for the slice
  (e.g., dock office folded into an exterior notice board)?
- **Sickroom access gating:** doorway-blocked-until-trusted — a hard block, or you can step
  in but the keeper steers you out until later?
