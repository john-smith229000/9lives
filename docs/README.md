# 9 Lives — Documentation Map

Index of the design & engineering docs. **Naming rule:** characters are referred to by
**role** (the keeper, the marina worker, the dock master, the fish seller, the café/bookshop
keeper, the grocer, the retiree(s), the mother) and **the friend** (the sick cat) — no
proper names until chosen.

## Layout

```
docs/
  README.md              this map
  STORY.md               canon premise/bible — start here
  ARCHITECTURE.md        codebase overview
  systems/               how the existing code works
  design/                mechanics, objects, puzzles
  story/                 narrative content & the arc
  slice/                 the buildable vertical slice
```

## Canon (start here)

| Doc | Purpose |
|---|---|
| **STORY.md** | The premise/bible: the loop, the spine (relight the beacon so the ship's vet can dock), locked decisions, open questions. Source of truth for canon. |
| **ARCHITECTURE.md** | Engineering overview of the codebase. |
| **gaps.md** | Production-readiness audit: unspecced systems, architecture decisions, UX gaps, story locks still open, and a suggested build order. Read before implementing Days 2+. |

## systems/ — how the existing code works

| Doc | Purpose |
|---|---|
| **flow_system_spec.md** | `SceneFlow` screenplay/orchestration + order-independent beats. |
| **dialogue_system_spec.md** | Dialogue box, `Interactable`, hints, interaction targeting. |
| **characters_spec.md** | `CharacterProfile` + the `Characters` autoload. |
| **jump_mechanic_spec.md** | The jump / hop / mount resolution. |

## design/ — mechanics, objects, puzzles

| Doc | Purpose |
|---|---|
| **gameplay.md** | Gameplay-first daily design: 10–20 min/day targets, verb toolbox, puzzle templates, object/state catalog, day-by-day tasks, engineering to-build. |
| **quest_web.md** | The interconnected quest web (dependency graph) and the nine-day rhythm. |
| **chain_quests.md** | Days 4–7 puzzle designs: each townsperson's problem as a concrete puzzle (objects, steps, timing, unlock) + story beat. |
| **task_ladder.md** | Day-by-day accounting: every task mapped to what it pays (Info/Access/Part/Fuel/Goodwill/Comfort), the goal it advances, the flag, and a running G1 checklist. |
| **locations_and_interiors.md** | Which buildings you can enter and how (doorway → free-move interior); the outdoor-grid vs indoor-free-move principle; interior contents per building. |
| **town_structures.md** | Physical catalog of every structure: geography/silhouette, materials & palette, per-structure details, and the broken→mended "town heals" states tied to persistence flags. |
| **objects_and_kinetics.md** | Carried items + kinetic objects (crates, barrels, buoy, etc.) with in-world reasons; signposted phase gates. |
| **barrel_and_checkpoints.md** | The heavy directional **barrel** spec, the **checkpoint** safety net, and the **buoy** (replaces the placeholder ball). |

## story/ — narrative content & the arc

| Doc | Purpose |
|---|---|
| **throughlines.md** | The whole-arc craft pass: theme, character motivation, the foreshadow & payoff ledger, the leak curve, gameplay↔theme cohesion, and the show-implicit/tasks-explicit + hint policy. Read this to see how it all ties together. |
| **continuity_audit.md** | Logic holes & their resolutions (the keeper as sole caretaker, why-not-just-light-it, the ship, the loop-break condition, etc.). |
| **cast.md** | Character bible — voice / want / wound / subtext for every role. Nameless. |
| **day1.md** | The full moment-to-moment Day 1 screenplay (gentle establishing day). Nameless. |
| **day2.md** | Full Day 2: the loop known, the first fix (marina slip), meeting the keeper. Nameless. |
| **day3.md** | Day 3 beat outline — "reaching": the tree lens, the grocer fetch, the vet clue. No scripted lines. |
| **day4.md** | Day 4 beat outline — the rats + the goal locking; the keeper-partner mirror. No scripted lines. |
| **day5.md** | Day 5 beat outline — the clever seal (rats gone for good); keeper thaw begins. |
| **day6.md** | Day 6 beat outline — the berth (barrel + winch + evening tide). |
| **day7.md** | Day 7 beat outline — the beacon assembly + the low point. |
| **day8.md** | Day 8 beat outline — the turn: light the beacon, choose to let tomorrow come. |
| **day9.md** | Day 9 beat outline — the ship, the arrival, the healed town. |
| **arc.md** | Day-by-day development for Days 2–9 + the arc weave; the imperfect-loop premise (the friend slips each loop). Nameless. |

## slice/ — the buildable vertical slice

| Doc | Purpose |
|---|---|
| **day1_vertical_slice.md** | Technical build plan for the Day-1 vertical slice in scene 6 (what's built, what's next). |

## Reading order for a newcomer

1. **STORY.md** — the premise and the loop.
2. **story/arc.md** — how the nine days and the arcs run.
3. **design/quest_web.md** — the quest web that structures those days.
4. **design/gameplay.md** — what the player does each day.
5. **design/objects_and_kinetics.md** + **design/barrel_and_checkpoints.md** — the object kit.
6. **story/throughlines.md** — theme, foreshadowing, and how it all coheres.
7. **story/cast.md** + **story/day1.md** — the people and the opening day.
8. **slice/day1_vertical_slice.md** — the slice being built first.
