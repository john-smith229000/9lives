# Day 3 — Reaching (beat outline)

Day 3: "reaching" — the first real forward motion, and the day the ship gets a *name*
(the traveling vet). **Beats are direction + intent, not scripted lines — dialogue is yours
to write.** `[GAME]` = mechanic foregrounded. Cross-refs `arc.md` (Day 3), `chain_quests.md`,
`../design/objects_and_kinetics.md`. Roles only.

## At a glance
- **Objective (told plainly):** recover the brass lens from the storm tree and the grocer's
  lost delivery from the rocks; return the delivery to the grocer; then find out about the
  incoming ship (dock register → café).
- **Shown, not told:** hope the cat distrusts; the café keeper's first flicker of déjà vu;
  the town's trade frozen (boats ready in cradles, nothing shipping).
- **If stuck (hints):** the marina worker names both targets and lends the crates; a light
  highlight on the tree / the crates to stack; the grocer and café point you to the
  register/manifest.

## Cast in play
The **friend** (home); the **marina worker** (freed crates); the **grocer** (oil + trap,
stranded delivery); the **dock master** (the register); the **café/bookshop keeper** (the
vet clue + first uncanny beat). The **keeper** referenced, not visited.

## MORNING
1. **Home — wake, with momentum.** Same dawn; but the cat wakes *faster* — yesterday's slip
   stayed cleared, so progress feels possible. Player takes the fish for the friend. Convey:
   the friend eats, but slower and less than Day 2 (the leak, one notch deeper). Leave.
2. **Marina — borrow the crates.** With the slip cleared (persisted), the freed
   **fish crates** are now available to move. The marina worker points the cat at what's
   been out of reach: the storm-tree in the square, and a delivery washed onto the rocks.
   *Sets the day's two reaching-puzzles.*

*→ phase tick: MORNING → MIDDAY.*

## MIDDAY
3. **The square — the storm tree.** `[GAME] stack + jump.` Push crates to the base of the
   big storm-struck tree, **stack** two, and **jump** to knock the **brass lens fitting**
   loose from the branches. Pick it up (**carry**). Convey: this is a piece of the
   lighthouse that literally fell into the town — the light, to be put back a piece at a
   time. Stash it (drop at a set spot; it persists as `lens_recovered`).
4. **The rocks — the stranded delivery.** `[GAME] crate bridge + jump.` The grocer's lost
   crate sits across a tidal gap below the wharf. Push crates into the gap so they **float**
   and lodge into a bridge, **jump** the last span, and reach the delivery (**carry** it).
   Note the carry constraint: you can't hold the lens and the delivery at once — sequence it
   (stash the lens first).
5. **General store — the payoff.** Return the delivery to the grocer at the counter. In
   thanks the grocer opens the **back storeroom**: the cat collects **lamp oil** and the
   **rat trap** (→ `oil_secured`, `has_rat_trap`). Convey the grocer's relief — the first
   thing "delivered" in ages, even if it came off a rock instead of a ship.

*→ phase tick: MIDDAY → AFTERNOON.*

## AFTERNOON
6. **Dock office — the register.** **Jump onto the dock master's desk** again; read the
   harbor ledger: a vessel is *listed and due*. Convey it as dry bureaucracy — the dock
   master won't editorialize — but the fact lands: a ship is expected.
7. **Café / bookshop — the name.** Cross-reference at the café: the incoming vessel is a
   supply-and-medical run — it carries a **traveling vet**. Convey the shift: the vague
   "help comes off the water" now has a shape and a purpose that maps onto the friend.
   `[GAME]` optional **read/browse** to surface the manifest/schedule (sets `learned_vet`).
8. **Café — the first uncanny beat.** The café keeper half-recognizes the cat / the
   conversation — a small "haven't we…?" flicker, brushed aside. First seed of the town
   sensing the loop. Keep it light and unresolved.
9. **The connection lands (narration/thought beat).** Reaching the vet means the ship must
   dock; the ship can't find the mouth in the fog without the **beacon**; the beacon is dark
   because the **keeper** won't light it. The objective clicks toward its final shape
   (fully locks Day 4). Convey hope the cat immediately distrusts.

*→ phase tick: AFTERNOON → EVENING.*

## EVENING
10. **The walk home (opt. quiet).** Hold on the dark lighthouse with new meaning — it's not just
    sad now, it's *the answer, unlit*. A hopeful heaviness. Head home.

## NIGHT
11. **Home — sleep.** Give the friend the day's gift and fish; convey they're touched but
    tired, engaging a little less than yesterday. Curl up → fade → loop.
12. **Wake — loop to Day 4.** Same dawn; the cat now carries a real objective (the ship /
    the light) and knows the oil, the trap, and the lens are secured going forward.

## Persists / advances
- **Persists:** `lens_recovered`, `oil_secured`, `has_rat_trap`, `learned_vet`.
- **Knowledge:** the ship = the vet = the hope; the beacon gates it; the keeper gates the
  beacon. Sets Day 4's goal-lock and the rat quest (you now hold the trap).
- **Leak:** the friend eats less again; the gift ritual gets a quieter response.

## Beat index
| # | Location | Who | Req? | Teaches / seeds |
|---|---|---|---|---|
| 1 | Home | friend | yes | leak deepens; momentum |
| 2 | Marina | marina worker | yes | crates available; the two targets |
| 3 | Square | — | yes | **stack + jump**; lens (persist) |
| 4 | Rocks | — | yes | **crate bridge + jump**; carry constraint |
| 5 | Store | grocer | yes | oil + trap (persist) |
| 6 | Dock office | dock master | yes | ship *listed/due* |
| 7 | Café | café keeper | yes | **the vet** (learned_vet) |
| 8 | Café | café keeper | opt. | first uncanny loop beat |
| 9 | — | — | yes | objective clicks toward final shape |
| 10 | Walk | — | opt. | the dark lighthouse reframed as "the answer" |
| 11–12 | Home | friend | yes | sleep; loop to Day 4 |

Spine: recover the lens (tree) and the delivery (rocks), collect oil + trap from the grocer,
learn the vet (register → café), home to sleep.
