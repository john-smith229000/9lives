# Day 1 — The Normal Day (full ~20–25 min plan)

Day 1 is the establishing day, the **tutorial**, and the **first case**: a full day in which
you search for help, do several real (if gentle) jobs around town — each teaching a verb —
and **investigate** why the town is the way it is, gathering clues into the **Journal** until
you can connect them. At dusk you carry a fish home to your friend and sleep, waking to the
**same dawn** (but the Journal *remembers*). Roles only; no cat dialogue (the cat's inner
monologue narrates; townsfolk speak). Tags: `[GAME]` verb taught · `[PUZZLE]`/`[TASK]` job ·
`[CLUE]` journal entry · `[DEDUCE]` combination. Uses `../design/clue_journal.md`.
PLACEHOLDER text — rewrite.

## At a glance
- **Objective (told plainly):** something's wrong with your friend — spend the day finding
  help, helping the town, and piecing together *why the harbour's gone quiet*; come home
  with a fish at dusk and rest.
- **Shown, not told:** a warm town that *cannot* help; the sea shut; the dark lighthouse; the loop
  (dawn resets what you did — but not what you know).
- **If stuck (hints):** the current job shows in the hint banner; open the **Journal (J/Tab)**
  to see what you've learned and what still doesn't add up; folk point you onward.

## Pacing budget (~20–25 min)
opening + **~6 puzzles/jobs** (2–4 min each, incl. a multi-step delivery chain) + **~8 clue
beats** + **2 deductions** + traversal + the evening fish + sleep. Order-tolerant; the day's
phases advance as jobs are done, reaching **evening** near the end (the fish); a key
**deduction gates** the wind-down so the investigation is mandatory, not optional.

## MORNING — wake & first steps
1. **Wake beside the friend.** Camera on them; they're unwell. Inner-monologue narration.
   → `[CLUE] friend_ill` ("something's wrong; the town's my only hope").
2. **Check on the friend** (interact): they deflect, send you to find help, ask for
   "something to look at." Sets the aim + opens the Journal.
3. **`[GAME] push + jump` — get out of the home lane.** A small two-verb intro: shove a crate
   under a broken step, hop up onto it and over. Teaches push and jump together, on zero stakes.

## MIDDAY–AFTERNOON — the town (jobs, puzzles, investigation; order-tolerant)

### A. The marina — the jammed slip  `[PUZZLE] push + plate/gate`
The slip is fouled by fish-crates and a stuck boom. **Weigh a pressure plate with a crate** to
hold the boom open, then **push** the remaining crates through in order to clear it. (First
real puzzle; introduces plates/gates.) → freed crates; `[CLUE] sea_shut` ("boats can't sail —
the harbour's closed") + the worker points you to the dock records.

### B. The delivery chain — a three-hop fetch across town  `[PUZZLE] carry + jump`
A classic adventure chain that stitches the districts together:
1. The **grocer** needs a crate that rolled onto a low roof/ledge — **stack a crate + jump**
   up, **carry** it down and back. → `[CLUE] supplies_low` + a **parcel** he can't deliver
   (roads/sea stalled).
2. **Carry the parcel** across town to the **café owner** (it was meant for them).
3. The café owner, in thanks, opens the back records → leads into puzzle **D**.

### C. The dock office — the register + the scattered pages  `[GAME] desk-jump` `[PUZZLE] traversal`
**Jump on the dock master's desk** → read the register: ships have stopped; a vessel was
*due*. → `[CLUE] ships_stopped`. His loose log pages blew across a **half-collapsed jetty** —
**cross the gaps (jump)** to collect 3 pages and bring them back → he lets you read the full
entry → `[CLUE] harbor_log` (the exact count of days since a ship came).

### D. The café / bookshop — the shelf search  `[PUZZLE] search`
Among the shelves, find the right record/book (a couple of wrong pulls first; light ordering)
→ `[CLUE] light_lore` ("the town was different before the light went out").

### E. The retirees — lore + a fetch  `[GAME] jump`
Knock down their thing stuck in a low branch (a jump); they reminisce about the lit beacon
and the keeper → `[CLUE] keeper_lore`.

### F. The fish seller — help now, fish later  `[TASK] carry`
Busy; no fish till evening (his refusal line). Help him — **carry/stack** his crates (or a
quick sort) — so he sets a fish aside for you this evening. → `[CLUE] tides` (the sea's rhythm).

### G. The cliff path — the dark lighthouse  `[GAME] examine`
**Examine** the unlit tower (a figure at the rail, gone; you can't get up). → `[CLUE]
beacon_dark`.

### Deductions (auto-formed as clues connect)
- `[DEDUCE] cut_off` = `sea_shut` + `ships_stopped` + `beacon_dark` → *"the harbour's been
  cut off since the beacon went dark."* **Gates the evening** (the day won't wind down until
  you've connected these — the investigation is required).
- `[DEDUCE] help_by_sea` = `friend_ill` + `no_doctor`(from the marina worker) + `sea_shut` →
  *"any real help has to come off the water."* Sets up Day 2's search.

## EVENING — the fish & home
4. **Collect the fish** (seller, now evening) → **carry** it home.
5. **Give it to the friend.** They eat; a quiet beat. Bring the "something to look at" too if
   you found one. → `[CLUE] resolve` ("tomorrow I keep looking").

## NIGHT
6. **Sleep.** Curl beside the friend → fade.
7. **Wake — the same dawn.** The world resets (fish gone, jobs undone, register blank) — **but
   the Journal is full.** *You have been here already, and this time you remember why it matters.*

## Mechanics taught on Day 1
move · interact · **push** · **carry** · **jump** · **plate/gate** · **search** · **desk-jump**
· **examine** · the **Journal (J/Tab)**. Later days build on all of it (barrels, rats, the
beacon) — Day 1 is where the whole vocabulary lands.

## The Journal on Day 1 (clues → deductions)
Clues: `friend_ill, sea_shut, ships_stopped, harbor_log, supplies_low, light_lore,
keeper_lore, tides, beacon_dark, no_doctor, resolve`.
Deductions: `cut_off` (gates evening), `help_by_sea` (seeds Day 2). Persist across the loop.

## Beat index
| # | District | Who/Prop | Kind | Teaches / grants |
|---|---|---|---|---|
| 1–2 | Home | friend | frame | aim; `friend_ill` |
| 3 | Home lane | crate/step | `[GAME]` | **push + jump** |
| A | Wharf | marina worker | `[PUZZLE]` | **push + plate/gate**; `sea_shut`, `no_doctor` |
| B | Store→Café | grocer, café owner | `[PUZZLE]` chain | **carry + jump**; `supplies_low` |
| C | Dock office / jetty | dock master | `[GAME]`+`[PUZZLE]` | **desk-jump, jump traversal**; `ships_stopped`, `harbor_log` |
| D | Café | café owner | `[PUZZLE]` | **search**; `light_lore` |
| E | Square | retirees | `[GAME]` | **jump**; `keeper_lore` |
| F | Market | fish seller | `[TASK]` | **carry**; `tides`; fish set aside |
| G | Cliff | dark lighthouse | `[GAME]` | **examine**; `beacon_dark` |
| — | — | — | `[DEDUCE]` | `cut_off` (gates evening), `help_by_sea` |
| 4–5 | Market→Home | seller, friend | frame | the evening fish |
| 6–7 | Home | friend | frame | sleep; the loop; Journal persists |

Spine to end the day: work the town's jobs (they gather the clues + carry the day to evening),
**connect the `cut_off` deduction**, collect the evening fish, bring it home, sleep. The
puzzles are the minutes; the investigation is the through-line; the fish + loop are the heart.

## Implementation note (new systems this "bigger" Day 1 needs)
- The **Journal** system (`../design/clue_journal.md`) — clues, deductions, UI, toast.
- **Plates + gates** (the slip puzzle) — extend the goal pad.
- A generic **`examine`** interactable + `grants_clues` on Interactables.
- The **delivery-chain** state (parcel = a carry item that specific NPCs accept).
- A **shelf-search** interaction; a **jump-traversal** stretch (gaps) on the jetty.
- Props/positions per district depend on your map blockout. See `../slice/day1_vertical_slice.md`.
