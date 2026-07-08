# Scene 6 — Day 1 Vertical Slice Plan

Status: **planning.** Target: one complete, playable **Day 1** loop in the harbor-town
map (`scenes/scene6.tscn`), placeholder art/dialogue OK. This slice exists to prove
the game's core novelty — *a day that ends when you sleep beside your friend, and
begins again at the same dawn* — is legible and good to play, end to end.

See `STORY.md` §2 (loop rules) and §5 (Day 1). This doc maps that onto the systems
already built (`SceneFlow`, `Dialogue`/`Interactable`, `Characters`, `GameState`,
`DayNightCycle`, `SceneManager`).

---

## 1. Definition of done (the playtest we're chasing)

A player can, without touching the keyboard debug keys, do this whole arc:

1. **Wake at dawn.** Scene opens on morning light, camera on the orange cat lying
   beside the grey-and-white **Friend**. A soft narration line sets the mood.
2. **Sense something's wrong.** Talk to the Friend (or simply approach — the friend
   cat already lies down when you come near). One line establishes they're unwell.
3. **Explore town.** Walk the harbor; talk to **1–2 townsfolk**. Their lines plant
   "there's no vet here" / "the town is your only help" without spelling out the ship.
4. **Head home.** Once the establishing beats are done, a non-blocking hint invites
   you home; time slides **morning → evening → night** as you go (phase-driven, not a
   clock).
5. **Sleep to end the day.** At home at night, press **I** on the Friend/bed to curl
   up. Screen fades to black.
6. **Wake at the same dawn.** The scene reloads to morning; a short reveal beat marks
   that *this is the same morning again* — the loop lands. The town is reset; only the
   cat "remembers" (a `GameState` flag drives the reveal line).

If that reads clearly and feels like a heartbeat rather than a chore, the slice is a
success. Everything below serves that.

**Explicitly out of scope for this slice:** the lighthouse repair chain, real puzzles,
persistence of physical repairs, the ship, days 2–9 content, final art. Those come
after the loop is proven.

---

## 2. What already exists vs. what's new

**Reuse as-is (proven in scene 1 / scene 3):**

- `SceneFlow` screenplay + order-independent `beat()`/`objective()`/`until_true()`.
- `Dialogue` + `Interactable` (walk up, face, press **I**) and non-blocking `hint()`.
- `Characters` autoload + `CharacterProfile` `.tres` (name/voice/expressions).
- `GameState` (`current_day`, `set_flag`/`has_flag`, `advance_day`, `reset`).
- `DayNightCycle` + `DayPhase` (sun/env presets, eased transitions).
- `SceneManager.reload()` / `goto_level()` and the persistent `game_root` host.
- Scene 6's ground/structures/water map and the placed `friend_cat`.
- Performance work already done (chunked grass, MSAA 4x, density variation).

**New for this slice:**

- **Flow-driven phase advance.** `DayNightCycle` only advances on the debug **T** key
  today. We need the *flow* (story progress) to drive morning→evening→night.
- **Sleep-to-end-day.** A trigger that, at night, ends the day: fade out →
  `GameState.advance_day()` → reload scene 6.
- **Day-transition fade.** A simple black fade for the sleep/wake cut (no fade system
  exists yet).
- **The Day 1 flow** (`scene6_flow.gd`) authoring all the beats.
- **Content:** character profiles + Day 1 placeholder lines for the Friend and 1–2
  townsfolk, and the "same dawn again" reveal.
- **Scene wiring:** enable `day_night_enabled`, author dawn/evening/night `DayPhase`s,
  co-locate the player's spawn beside the Friend at "home," place the townsfolk, and
  confirm the town is navigable.

---

## 3. Beat sheet (the Day 1 screenplay)

Authored in `scene6_flow.gd extends SceneFlow`, order-independent per the flow spec.
Pseudocode using the real `SceneFlow` API — tune wording/timing later.

```gdscript
func _run() -> void:
    var friend := world.get_node_or_null("friend_cat")
    var friend_talk := friend.get_node_or_null("Talk")      # new Interactable
    var fishmonger := world.get_node_or_null("Fishmonger")  # placed townsfolk
    var bookseller := world.get_node_or_null("Bookseller")

    # Objectives are LIVE predicates (correct in any order).
    objective(&"greeted_friend", func(): return friend_talk and friend_talk.has_talked())
    objective(&"met_someone",   func(): return _talked_to_any([fishmonger, bookseller]))

    # --- WAKE: branch on whether we've looped before ---
    if GameState.current_day == 1:
        camera_focus(friend)
        await say("", ["Dawn. Your friend stirs beside you, breathing shallow."])
        camera_release()
    else:
        # We've slept and come back — the reveal that it's the SAME morning.
        camera_focus(friend)
        await say("", ["...Dawn again. The same dawn. Your friend, exactly as before."])
        camera_release()
        GameState.set_flag(&"s6_loop_noticed")

    # --- ESTABLISH: friend is unwell ---
    await beat({"objective": &"greeted_friend", "highlight": friend})
    GameState.set_flag(&"s6_checked_friend")

    # --- EXPLORE: meet the town (any townsperson counts) ---
    hint("Look around the harbor. Someone might know how to help.")
    await beat({"objective": &"met_someone"})
    hide_hint()

    # --- HEAD HOME: progress advances time, not a timer ---
    world.advance_time_phase()                 # morning -> evening   (NEW World API)
    hint("Evening. Head home to your friend and rest.")
    # objective: player is back on the "home" tile next to the friend
    objective(&"home", func(): return _player_near(friend, 1))
    await until_true(func(): return is_done(&"home"))
    world.advance_time_phase()                 # evening -> night
    hide_hint()

    # --- SLEEP: end the day ---
    hint("Curl up beside your friend to sleep. [I]")
    objective(&"slept", func(): return friend_talk and friend_talk.used_after())  # or a Bed
    await until_true(func(): return is_done(&"slept"))
    await world.end_day()                      # fade to black, advance_day, reload (NEW)
```

Notes:

- The wake branch is the whole trick: **same script, different opening line** based on
  `GameState.current_day`. Day 1 establishes; day > 1 reveals the loop. The town
  content is identical because the world reset.
- Keep it **adapt-not-prevent** (flow spec §"Adapt vs. prevent"): talking to townsfolk
  in any order, wandering off and back — all fine. Nothing here is unrecoverable.
- `say("", [...])` with an empty speaker = narration (no name). Confirm the dialogue
  box renders a blank speaker acceptably; if not, use a `"Narrator"` profile or a
  dedicated narration style (small polish task).

---

## 4. Build tasks

### A. Scene wiring — `scenes/scene6.tscn`

- [ ] **Enable day/night:** set `day_night_enabled = true` on the World node.
- [ ] **Author phases:** add a `day_phases` array of `DayPhase` resources — for the
      slice, three is enough: **Dawn/Morning**, **Evening**, **Night** (you can start
      from the built-in defaults in `day_night.gd::_default_phases()` and trim to 3).
      The flow drives transitions, so order them morning→evening→night.
- [ ] **Home spot:** decide a "home" tile (a house on the structures mesh) and move the
      **Player** spawn to be adjacent to the **friend_cat** so you literally wake beside
      it. Today: Player at `(50,1,50)`, friend at `(58,74)` — co-locate them.
- [ ] **Place townsfolk:** instance 1–2 talkers the way scene 1 places its villager —
      an NPC/Node3D with a `Model` child + an `Interactable` child (`speaker`, `lines`,
      `profile`). Name them (`Fishmonger`, `Bookseller`) so the flow can find them.
- [ ] **Friend talkable:** add an `Interactable` child to `friend_cat` (name it `Talk`)
      so you can "check on" it and, at night, "sleep" (see §B sleep trigger). Set
      `snap_to_surface` appropriately (the friend already sits on the map).
- [ ] **Navigation check:** scene 6 uses `follow_map_height` but not `confine_to_land`.
      Verify the cat can path across town and can't walk off the map / onto water in a
      way that strands the slice. If it can wander off, set `confine_to_land = true`
      and tune `sea_level`, or add `hole/water` where needed.
- [ ] **Add the flow node:** a child of the World node named `Flow` with
      `scene6_flow.gd` attached (§D).

### B. New mechanics

**B1. Flow-driven phase advance** (`scripts/world/world.gd` + `day_night.gd`)

- [ ] Add a public World method the flow can call, e.g.
      `func advance_time_phase() -> void: if _day_night: _day_night.advance()`.
      Optionally `func set_time_phase(index)` for precise control.
- [ ] Keep the debug **T** key working for authoring, but the slice should reach night
      through `advance_time_phase()` from the flow, not the key.
- [ ] (Optional) Have the opening phase be forced to Morning on load
      (`_day_night` already applies `_phases[0]` at setup — just author Morning first).

**B2. Sleep-to-end-day** (`scripts/world/world.gd`, new fade helper)

- [ ] Choose the sleep trigger. Simplest: reuse the Friend's `Interactable` — when its
      conversation ends **and** the current phase is Night **and** the player is home,
      the flow calls `world.end_day()`. (Alternatively add a dedicated `Bed`
      Interactable.) The `Interactable` already exposes `talked` /
      `conversation_ended` / `use_after_lines()` — use `use_after_lines()` to swap to a
      "you settle in to sleep…" line at night.
- [ ] Implement `World.end_day()`:
      1. `await` a screen fade to black (B3).
      2. `GameState.advance_day()` (loop counter 1 → 2; the *world* still resets to the
         same dawn — that's the story).
      3. `SceneManager.reload()` to rebuild scene 6 fresh (town resets for free).
- [ ] Because `GameState` is an autoload, `current_day` + flags **survive the reload**;
      the reloaded `scene6_flow` reads `current_day > 1` and plays the reveal.

**B3. Day-transition fade** (`scripts/fx/screen_fade.gd` — new, small)

- [ ] A tiny helper: a `CanvasLayer` + full-rect `ColorRect` (black) with a `fade_out`/
      `fade_in` tween returning when done. Add it inside the level (it will render into
      the retro SubViewport, which is fine — it fades the game image before reload).
- [ ] Expose `await fade.to_black(secs)` / `await fade.from_black(secs)`; `end_day()`
      fades to black, and on the next scene the flow (or World `_ready`) fades back in.

**B4. Loop reveal** — no new system; handled by the `current_day` branch in the flow
(§3) plus `GameState`. Consider a `GameState.set_flag(&"s6_day1_done")` on first sleep
so later days/branches can key off "the loop has been noticed."

### C. Characters & dialogue content

- [ ] **Friend profile** — duplicate `characters/bob.tres` → `characters/friend.tres`
      (`id="friend"`, display name TBD — see §5 names). Expressions can stay minimal;
      the story lines live on the `Interactable`/flow.
- [ ] **Townsfolk profiles** — `fishmonger.tres`, `bookseller.tres` (or reuse
      `bob`/`john` as placeholders to move fast). Give each a one-line personality.
- [ ] **Day 1 lines (placeholder, but in-voice):**
  - Friend (checked on): unwell, tired, trusting — 1–2 lines.
  - Fishmonger: weather/tides flavor + "no doctor for a cat here."
  - Bookseller: watchful, hints the town holds answers if you keep looking.
  - Narration: the two wake lines (day 1 vs. looped) and the "settle in to sleep" line.
- [ ] Decide narration presentation (empty speaker vs. a `Narrator` profile) — see §3.

### D. The flow script — `scripts/flow/scene6_flow.gd`

- [ ] `extends SceneFlow`; implement `_run()` from the §3 beat sheet.
- [ ] Small private helpers: `_talked_to_any(nodes)`, `_player_near(node, tiles)`
      (use `world.cell_size` + `tile_of()`), matching scene 1's style.
- [ ] Set `GameState` flags at each meaningful beat (`s6_checked_friend`,
      `s6_met_town`, `s6_loop_noticed`, `s6_day1_done`).
- [ ] Register in scene 6 as a child of `World` named `Flow` (per flow spec).

### E. Camera / feel

- [ ] Opening `camera_focus(friend)` → narration → `camera_release()` (mirrors scene 1's
      intro camera). Reuse `Timing` presets so the feel matches the rest of the game.
- [ ] Optional: a brief `camera_hold` over the harbor/lighthouse silhouette during the
      "explore" hint, to plant the beacon for future days (pure foreshadowing, cheap).

---

## 5. Design decisions to lock before/while building

These are from `STORY.md` §7; the slice needs a provisional answer for each (all
reversible):

- **Does sleeping advance `current_day`?** Recommended **yes** — `current_day` is the
  loop counter (1→9), while the *world* resets to the same dawn. This gives the flow a
  clean signal for the reveal and matches the 9-loop structure.
- **Friend's condition:** **cosmetic/dialogue only** for the slice (no mechanical
  penalty), per §6's gentler option. Keeps Day 1 a calm establishing beat.
- **Names** (needed for dialogue): town, the two cats. Placeholders are fine to start
  (e.g. Friend = "Momo"), but pick something so lines read naturally.
- **How much persists:** the slice only needs **knowledge/flags** to persist (the loop
  reveal). Physical-repair persistence is a later-day concern — don't build it here.
- **Reveal wording/tone:** understated (the story's whole voice). One or two lines, no
  explanation of *why* the loop happens.

---

## 6. New / touched files

**New:**

- `scripts/flow/scene6_flow.gd` — the Day 1 screenplay.
- `scripts/fx/screen_fade.gd` — reusable fade-to/from-black helper.
- `characters/friend.tres` (+ `fishmonger.tres`, `bookseller.tres` if not reusing).

**Touched:**

- `scenes/scene6.tscn` — enable day/night + phases, relocate player spawn, place
  townsfolk + friend `Interactable`, add the `Flow` node.
- `scripts/world/world.gd` — `advance_time_phase()`, `end_day()` (fade → advance_day →
  reload); maybe a `set_time_phase()`.
- `scripts/world/day_night.gd` — (only if you want a `set_phase(index)` for the flow).
- Possibly `scripts/dialogue/dialogue_box.gd` — narration styling if empty-speaker
  isn't clean (polish, optional).

---

## 7. Suggested build order (milestones)

1. **Greybox the loop (no content).** Add `end_day()` + fade + `advance_time_phase()`;
   a throwaway flow that advances to night on a key and sleeps → reload. Confirm
   `GameState.current_day` increments and the reload wakes you at morning. *This is the
   riskiest, most novel piece — prove it first.*
2. **Wake reveal branch.** Make the flow open differently on `current_day > 1`. Confirm
   the "same dawn again" line only appears after a sleep.
3. **Populate the day.** Relocate spawn beside the Friend; add the Friend `Interactable`
   and 1–2 townsfolk with placeholder lines; wire the explore/home/sleep objectives.
4. **Feel pass.** Opening camera beat, hints, phase timing, narration wording.
5. **Playtest against §1** and adjust.

Milestone 1 is the whole ballgame — if the sleep→reload→same-dawn loop feels right,
the rest is authoring.

## 8. Playtest checklist

- [ ] Fresh **New Game** starts at `current_day == 1` (start menu already calls
      `GameState.reset()`).
- [ ] Opening: morning light, camera on Friend, day-1 narration.
- [ ] Can talk to the Friend and to each townsperson; lines read correctly; movement/
      camera freeze during speech and resume after.
- [ ] Doing beats **out of order** (townsfolk before Friend, wandering off mid-hint)
      never strands an outline or hangs the flow.
- [ ] Time only advances via progress/heading home — never a real-time timer.
- [ ] Sleeping at night fades to black and reloads; you wake at **morning**, not night.
- [ ] Second morning plays the **loop reveal** line; the town is reset (NPCs/props back
      to start); the cat "remembers" (reveal only fires because a flag persisted).
- [ ] Frame rate in scene 6 stays smooth throughout (grass work already landed).

## 9. Gotchas / watch-outs

- **Order-independence:** author every gate as a live `objective()` and skip beats with
  `is_done()` — never assume the player waited for the script (flow spec §"Order-
  independence").
- **Phase vs. timer:** resist any real-time countdown; night is reached by calling
  `advance_time_phase()` at story beats only.
- **GameState survives reload, resets on New Game only:** don't call `GameState.reset()`
  on the sleep reload — only the start menu's New Game should reset. `advance_day()` +
  `SceneManager.reload()` is the sleep path.
- **Fade + retro SubViewport:** the fade renders inside the low-res stage; that's fine
  for the slice. If you later want the fade to cover menus too, move it up to the
  `game_root` MenuLayer.
- **Friend `Interactable` doubling as the bed:** make sure the "check on friend"
  conversation (daytime) and the "sleep" action (night) don't collide — gate the sleep
  branch on the Night phase and the home objective, and use `use_after_lines()` to swap
  the friend's line to the sleep prompt at night.
- **Navigation:** verify the harbor is actually walkable end-to-end before authoring
  positions, or you'll place a townsperson somewhere the cat can't reach.
