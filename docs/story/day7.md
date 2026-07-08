# Day 7 — The Beacon (beat outline)

Day 7: assemble the light — everything but the flame — and hit the low point. **Beats are
direction + intent, not scripted lines.** `[GAME]` = mechanic foregrounded. Cross-refs
`arc.md`, `chain_quests.md` (Day 7), `../design/locations_and_interiors.md` (the tower
interior). Roles only.

## At a glance
- **Objective (told plainly):** comfort the keeper's sick partner, find the keeper's
  abandoned tower key in the cottage, then assemble the beacon — fuel it (oil), fit the lens,
  crank it ready.
- **Shown, not told:** the mirror made literal (you comfort the partner as you do the
  friend); the low point (everything mended, still dark); the keeper's despair.
- **If stuck (hints):** the keeper indicates what the partner needs; once allowed in, the key
  glints by the bed / on its hook; the beacon parts give clear prompts (tank, lens, crank).

## Cast in play
The **friend** (home); the **keeper** and their **sick partner** (the trust gate); the
**marina worker** (the permanent bridge). Combines every verb learned so far.

## MORNING
1. **Home — wake.** Same dawn; fish to the friend (leak: barely touched). Convey the cat's
   nervy focus — today the light itself.
2. **The bridge made permanent.** `[GAME] persistent swap.` In **daylight**, the marina
   worker lays a real **plank** over the cliff-gap where you've box-bridged all week →
   `bridge_permanent`. Convey the town literally getting easier: a walk where there was once
   a puzzle.

*→ phase tick: MORNING → MIDDAY.*

## MIDDAY  *(earn the way in)*
3. **The foot cottage — comfort the partner, find the key.** Comfort the keeper's **sick
   partner** (carry **fish**, set the bedside **trap**, and — the real thing — **curl up
   beside them**, the way you do your friend). This eases the keeper enough to let you deeper
   into the cottage, and there — by the bed / on its old hook — is the **key the keeper
   stopped wearing**. You **find** it and pick it up (`keeper_trust` completes →
   `has_tower_key`). Convey that it's not given to you; you find the thing they'd given up on.

## AFTERNOON  *(the tower — interior, free-move)*
4. **Unlock the tower.** The **tower door** opens with the key. Enter (interior / free-move).
5. **Fuel it.** `[GAME] barrel → carry.` **Roll the oil barrel** to the tower foot and
   **tap** it; **carry** oil cans up the now-permanent stair and **fill the tank** (several
   trips — the one-item carry paces the finale).
6. **Glass it.** `[GAME] carry + use.` **Carry the lens fitting** (from Day 3) up and
   **seat** it; **crank** the hoist to raise the lens into the lamp; hold the **vent** with a
   crate on a **plate**. → `beacon_ready`. Everything is in place — except the fire.
7. **The keeper in the lantern room — the low point.** The keeper comes up (or is there),
   and convey their despair aimed at you: the light is ready, and they believe it will call
   into the dark and be answered by nothing. Convey that the cat has done every *repair* —
   and the one thing left isn't a repair at all. Seed the turn without taking it.

*→ phase tick: AFTERNOON → EVENING.*

## EVENING
8. **Down from the tower (heavy beat).** Convey the exhaustion of standing in a finished,
   dark lighthouse: you fixed the whole machine and it's still night. The last step is
   letting go — and by now the friend is barely eating, so *staying* isn't safe either.

## NIGHT
9. **Home — sleep, differently.** The friend, very weak, is tender; convey a near-recognition
   — that you keep looking at them like a goodbye. You don't light the beacon tonight; you go
   home. Curl up → fade → loop.
10. **Wake — loop to Day 8.** Everything is ready. Only the flame — and the choice — remain.

## Persists / advances
- **Persists:** `bridge_permanent`, `has_tower_key`, `beacon_ready`.
- **Town heals:** the tower's glass + lamp visibly restored (still unlit); the stair a real
  bridge.
- **Low point:** everything mended, still dark — the last step is hope, not repair.
- **Leak:** friend barely eats; the goodbye-look beat lands.

## Beat index
| # | Location | Who | Req? | Teaches / seeds |
|---|---|---|---|---|
| 1 | Home | friend | yes | leak near-bottom |
| 2 | Cliff path | marina worker | yes | **bridge_permanent** |
| 3 | Foot cottage | keeper / sick partner | yes | comfort the partner → **find the key** |
| 4 | Tower door | — | yes | interior unlock |
| 5 | Tower | — | yes | **barrel → carry oil** (fill tank) |
| 6 | Lantern room | — | yes | **carry + crank + plate** (lens) → beacon_ready |
| 7 | Lantern room | keeper | yes | the low point; the turn seeded |
| 8 | Down | — | yes | finished-but-dark heaviness |
| 9–10 | Home | friend | yes | goodbye-look; loop to Day 8 |

Spine: permanent bridge → comfort the partner + find the key → fuel + glass + crank the beacon → stand in
the dark. All but the flame.
