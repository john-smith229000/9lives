# Clue & Journal System

The investigation mechanic. The cat can't speak, but it **notices** — and the **Journal is
the cat's memory**, the one thing that carries across the loop. Gathering clues is the
detective layer; combining them into **deductions** drives understanding and gates progress.
Because knowledge always persists (the premise), the Journal **accumulates across all nine
days** — it's "only the cat remembers," made mechanical and visible.

## Why it fits
- The loop's rule is *the cat keeps its memory*. The Journal is that memory on screen — it's
  the diegetic reward for looping and the tool that makes the mystery solvable over days.
- It gives the silent-cat investigation real texture: not "talk to everyone," but "notice,
  connect, conclude."

## Data model
- **Clue**: `id` (StringName), `title` (short), `note` (the cat's phrasing — inner
  monologue), `category` (The Friend / The Town / The Sea & the Ship / The Light),
  `source` (who/where it came from), `discovered` (bool), `unread` (bool, for the dot).
- **Deduction**: `id`, `requires` (Array of clue ids), `title`, `note`, `unlocked` (bool).
  When every required clue is known, it **auto-unlocks** (a small "…oh" beat).
- Store as **data**, not code: a `res://clues/*.tres` set (like `characters/*.tres`),
  auto-loaded by the Journal. Writing/editing clues becomes inspector work and scales with
  the nine-day investigation. (A single JSON keyed by id is a fine alternative.)

## `Journal` autoload  *(sibling of `GameState`)*
- `discover(id)` — mark a clue known, set `unread`, re-check deductions, emit `clue_added(id)`.
- `has_clue(id)`, `has_deduction(id)`, `clues_in(category)`, `all_deductions()`, `unread_count()`.
- **Deduction check:** after each `discover`, scan deduction rules; auto-unlock any whose
  `requires` are all met; emit `deduction_made(id)`.
- **Persistence:** the Journal is **NOT reset on sleep** (knowledge carries across loops).
  `reset()` only on **New Game** (call it alongside `GameState.reset()`).

## UI
- **Journal screen** — a `CanvasLayer` toggled by a new `journal` input action (J / Tab).
  Overlays (light pause). Clues listed by **category**, deductions in their own panel,
  unread items dotted. Built in code (like the dialogue box) to avoid scene-anchor gotchas.
- **New-clue toast** — a small banner (reuse the hint styling) when a clue or deduction is
  gained ("Noted." / "That connects…"), plus an **unread pip** on the HUD so the player
  knows to open the Journal.
- **Voice:** every clue/note is the cat's own observation (silent-cat model). No NPC voice
  in the Journal.

## How clues are gained
- **Talk:** an `Interactable` gets an optional `grants_clues: Array[StringName]` — awarded on
  conversation close (`on_conversation_closed`). So townsfolk hand you clues by talking.
- **Observe / examine:** a lightweight `examine` interactable (or the `on_cat_interact`
  hook) on a prop/spot — the register, the dark lighthouse, a notice board, the tide-line — grants
  a clue when inspected.
- **Puzzle / task completion:** finishing a job can `Journal.discover(...)`.
- **Deductions:** formed automatically from combinations (no player action).

## Gating progress with clues
- Flows/objectives can require `Journal.has_clue(x)` or `has_deduction(y)` — making the
  investigation **mandatory**, not flavor.
- **Day 1 example:** the day can't wind to evening until you've formed the deduction
  **"the town's been cut off since the light went dark"** (needs the *sea-shut* + *ships-
  stopped* + *beacon-dark* clues). You can gather them in any order, but you must connect them.
- **Later days:** deductions unlock the **vet** realization (Day 2–3), the beacon plan, the
  keeper's situation, etc. The nine-day mystery is a growing deduction tree.

## Across the loop (the payoff)
The Journal never empties between loops, so Day 2 opens on a page already full — the cat
*remembers*. New clues layer on top; old deductions stand. The café/bookshop keeper's uncanny
"haven't we…?" is the town half-sensing what your Journal makes explicit. On the final days,
the page is a dense map of everything you pieced together across repeats.

## Build notes (new work)
- **`Journal` autoload** + clue/deduction data (`clues/*.tres` set or a JSON).
- **Journal UI** (CanvasLayer + toggle) + the **new-clue toast** + an **unread pip**.
- **`journal` input action** (bind J / Tab) in `project.godot`.
- Hooks: `Interactable.grants_clues`; a small **`examine`** interactable for observe-clues.
- Wire into New Game reset (clear Journal with GameState).
- Priority: **P1 for the "bigger" Day 1** (the investigation depends on it); it then serves
  the whole nine-day arc.
