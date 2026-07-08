# Day 1 Vertical Slice — Full Implementation Plan

Everything needed to build **Day 1 as designed** (the gentle town-tour establishing day),
end to end, across every discipline. Design source: `../story/day1.md` (beats),
`../story/throughlines.md`, `../design/task_ladder.md`, `../design/locations_and_interiors.md`,
`../design/town_structures.md`. Systems reality-check: `../gaps.md`.

Legend: **[HAVE]** already built · **[NEW]** to build · **[ART]** asset/model · **[WIRE]**
scene setup · **[CONTENT]** authoring.

---

## 0. Scope — what the Day-1 slice is (and isn't)

**In:** wake inside the home beside the sick friend → carry a fish home for them → tour the
town meeting the folk (order-tolerant) → the dark tower glimpsed → evening → sleep → **wake
to the same dawn** (the loop lands). ~10–15 min. Proves the *feel*: the loop, the warm-but-
powerless town, the ache — with the minimum systems.

**Out (deferred to later days, NOT needed for the slice):** rats/traps, barrels, buoys,
pressure-plates/gates, tide gates, the berth, the beacon assembly, the keeper *conversation*
(Day 1 is glimpse-only), the whole chain. Also out: save-to-disk, per-day content config,
friend decline model (Day 1 is baseline — the friend eats normally).

**The one genuinely new mechanic the slice needs: carry-in-mouth** (for the fish). Almost
everything else is reuse + content + placement.

---

## 1. Mechanics

**[HAVE] reuse as-is:** grid + click-to-move; **talk** (Interactable/InteractionController);
jump; **push** a crate; **day/night phases** + `advance_time_phase`/`set_time_phase`;
**ScreenFade** + `start_faded` (wake fade-in); **friend_cat** gated `start_asleep`/
`enable_sleep`/`curled_up`; **`end_day()`** (nightfall → fade → `advance_day` → reload);
SceneManager reload; the hint banner.

**[NEW] Carry-in-mouth (slice version — the fish):**
- One **`carried`** slot on the player (item id or none).
- **Pick up:** press Interact facing a source (the fish seller's stall) → the fish attaches
  to a mouth point on the cat model.
- **Give / drop:** press Interact facing the target (the friend's dish at home) → the item
  transfers/placed; or drop on empty ground.
- **Constraints:** can't push or start a jump while carrying (or it drops); one item only.
- **Hooks:** an attach node on the cat's head/mouth; a small `Carryable` component
  (id + mesh); reuse Interactable targeting for pick/give. *(This is the slice's only new
  system — keep it minimal; a fuller spec can come later — see `../gaps.md` §1.)*

**[NEW] The "same dawn" reveal (light):** on `end_day` set a couple of `GameState` flags for
what you did this loop (`s6_gave_fish`, `s6_met_town`); on reload, if `current_day > 1`, the
flow plays the reveal narration and can reference those (the fish you left is gone, etc.).
The world already resets via reload — this just *tailors the narration* to what you did.

**[NEW/light] Objective surfacing:** reuse the hint banner to show each day's objective +
escalating hints (from `day1.md`'s "At a glance"). A persistent one-line objective HUD is
optional polish.

**[WIRE] Tuning:** Day-1 phase durations (currently 30s — consider ~15–20s for the slice so
the tour doesn't drag); the "meet the town" order-tolerant count that ticks the phase.

---

## 2. Flow / scripting  `scripts/flow/scene6_flow.gd`  **[NEW rewrite]**

Replace the greybox flow (ball/crate/placeholder James) with the Day-1 tour:
1. **Wake** (fade-in handled by World): camera on the friend; opening narration beat.
2. **Check on the friend** (Interactable on `friend_cat`): they deflect, ask for "something
   to look at," ear up. Sets `s6_checked_friend`.
3. **Carry tutorial:** hint to take the fish from the seller and bring it home; `carried`
   fish → give at the dish → `s6_gave_fish`. Friend eats it (baseline, no decline).
4. **Meet the town** (order-tolerant): objectives per townsperson (`met_marina`,
   `met_dock`, `met_fish`, `met_grocer`, `met_cafe`, opt. `met_retiree`). A **phase ticks**
   at each district seam. Optional: shove the marina worker's crate (`s6_crate` — reuse the
   built crate).
5. **Cliff path glimpse:** reach it → the dark tower + one lit window + the keeper figure
   (no conversation). `s6_saw_tower`.
6. **Evening → home:** hint to head home; walk past the mother's lit window/empty table.
7. **Sleep:** curl by the friend (`friend.enable_sleep()` → `curled_up`) → `world.end_day()`.
8. **Reload / Day 2 dawn:** if `current_day > 1`, the **same-dawn reveal** narration.

Order-tolerant per `SceneFlow` (live `objective()` predicates, `beat()` skips if done). Uses
the `At a glance` objective/hint text.

---

## 3. Characters & dialogue

**[WIRE] Place as talkables** (each = `npc.tscn` instance + a `Talk` `Interactable` child,
like scene 1's villager): **marina worker, dock master, fish seller, grocer, café keeper,
retiree(s)**. The **friend** (`friend_cat` + a new `Talk` child). The **keeper** = a static
figure at the tower rail (no Interactable — glimpse only).

**[CONTENT] CharacterProfiles** (`characters/*.tres`): one per role for the name shown in the
box (placeholder = the role, e.g. "Fishmonger"); voice blank for now; expressions optional.
Or reuse `bob`/`john` as stand-ins to move fast.

**[CONTENT] Dialogue:** placeholder lines per NPC from the `day1.md` beat intents (final lines
are yours to write — docs are beats-only per your call). The slice needs at least stubs so the
box shows something. The **cat is silent** (narration only); NPCs speak.

---

## 4. Environment / level blockout  `scenes/scene6.tscn` + the scene-6 map  **[WIRE]**

The town map GLBs exist (`scene6ground/structures/water.glb`); what's missing is the
**layout pass** — placing districts so the tour reads and paths connect:
- **Home cottage** (harbor edge, at/near the player spawn) — interior (see §5).
- **Wharf / marina** (marina worker; the optional crate).
- **Big dock + office** (dock master; the desk — see §5).
- **Fish stall** (fish seller; the fish pickup).
- **General store** (grocer).
- **Café / bookshop** (café keeper; the two cups).
- **Square** (retirees).
- **Cliff path + dark lighthouse** (glimpse; keeper figure; one lit window).
- **The mother's house** (exterior: a lit window + a table set — dressing, met properly Day 4).

**[WIRE] Navigation:** confirm walkable routes between all of the above; set `confine_to_land`
/ blockers so the cat can't wander off the map; verify the scene-6 mesh supports the tour.
**Player spawn beside the friend at home.** Keep the **dark tower in most sightlines**.

---

## 5. Interiors

**[HAVE] template:** `house_controller.gd` + `house1.tscn` (doorway trigger → fade → interior
camera → free-move).

- **Home cottage [NEW interior]:** the emotional anchor — wake and sleep here. Contents: the
  friend's **blanket-nest** by a window, the **fish dish**, a **gift shelf**. Wire a
  `HouseController` (player + exterior cam + house + doorway trigger + `inside_view` cam).
  **Integrate the loop:** wake = fade-in on the interior camera (reuse `ScreenFade`/
  `start_faded`); sleep = curl by the nest → fade-out → `end_day` reload. **Test that a
  carried fish survives the doorway** (into home to the dish).
- **Dock office [NEW small interior]:** for the **desk-jump** beat — the dock master at a desk
  with the open register; the cat jumps on the desk to interact/read. Small room + controller,
  or a doorway-peek if trimming scope.
- **Café / grocer:** for the slice, keep **exterior** (talk at the stall/doorway) to bound
  scope — make them full interiors later. *(Scope choice — flag if you want them enterable
  now.)*

---

## 6. Models / assets / props

**[HAVE]:** `cat.glb` (player), `friend_cat.glb` (the friend), `npc1.glb` (townsfolk),
`crate.glb`, `house1.glb` (home template), scene-6 town GLBs, tiles, grass, `arrow.glb`,
`ball.glb` (cut from Day 1 — see §11).

**[ART] new for Day 1:**
- **Fish** (carry item) — small mesh, attaches to the cat's mouth point.
- **Fish dish** (home) + **gift shelf** + a placeholder **gift** (shell/feather).
- **Dock master's desk + register/ledger** (interactable prop).
- **Café counter + two cups** (if café featured; one cup "cold").
- **Mother's window + lamp + a set table** (exterior dressing).
- **Dark lighthouse tower + one lit (emissive) window** — confirm it's in
  `scene6structures.glb`; if not, add the tower model + emissive window material.
- **Keeper figure** at the rail — reuse `npc1.glb`, static/idle.
- **Townsfolk variety** — reuse `npc1.glb` with **tint/props (hats, aprons)** to tell the ~6
  roles apart (placeholder-friendly).
- **Mouth attach point** on the cat rig for carried items.

---

## 7. Environment art & mood  **[WIRE/ART]**

- **Day-1 DayPhase presets** (author in `day_phases`): **Dawn/Morning** (thin silver),
  **Midday** (flat grey), **Afternoon** (one gold hour), **Evening** (gold drains), **Night**
  (the fade). Drives sun angle/energy/colour + ambient + sky.
- **Fog:** a subtle environment fog / distance fade (part of the mood; also motivates "the
  ship can't find the mouth"). Tune per phase (thins midday, thickens evening).
- **Window glows:** emissive materials for the lit windows (the tower's one window; the
  mother's lamp) — the main warmth against the grey.
- **Grass/cloud shadows:** already in scene 6 (perf-tuned) — leave on.

---

## 8. UI  **[NEW light]**

- **Objective + hints:** reuse the Dialogue **hint banner** for the day's objective and the
  escalating "if stuck" nudges. Optional: a small persistent objective line.
- **Interaction prompt** (press I) — exists.
- **Optional:** a "Day 1" title card on first wake; a subtle time-of-day indicator.

---

## 9. Audio  **[ART/CONTENT, placeholder ok]**

- **Ambience loop:** fog/sea wash + occasional gulls — and the **deliberate absence of a
  ship's horn** (the motif Day 9 pays off; nothing to author, just *don't* play one).
- **Footsteps** (exist), **dialogue blips** (per profile — optional).
- **Fade stingers:** a soft cue on the sleep fade-out and the wake fade-in.

---

## 10. Scene wiring checklist  `scenes/scene6.tscn`  **[WIRE]**

- Player spawn **beside the friend at home**; `day_night_enabled` + the Day-1 `day_phases`;
  `start_faded = true`; the **`Flow`** node (`scene6_flow.gd`).
- Place all **NPCs + `Talk` Interactables** (§3) and **props** (§6) in their districts (§4).
- **Home interior** + `HouseController`; **dock office** interior/desk.
- The **dark tower + keeper figure + lit window**; the **mother's window/table**.
- The **fish pickup** at the stall; the **dish** at home.
- (Optional) the marina worker's **crate** for the push favor.

---

## 11. What to change from the current greybox scene 6
- **Cut the ball** from Day 1 (it's a later-day mechanic).
- **Reframe/keep the crate** as the marina worker's *optional* favor (not a gated goal); the
  goal-pad can stay for that or be dropped.
- **Replace placeholder "James"** with the real cast by role (marina worker et al.).
- **Move the friend indoors** (home interior) from the current exterior placement.
- **Rewrite `scene6_flow`** from the greybox to the tour (§2).

---

## 12. Definition of done (playtest)
A player, no debug keys, does: wake inside beside the friend → take the fish from the stall
and give it at the dish → meet the town (any order) → glimpse the dark tower → head home in
the evening → curl up → **wake to the same dawn**, with narration noticing what reset. Runs
~10–15 min, order-tolerant, no soft-locks, smooth frame rate. It should *feel* like the game.

## 13. Build order (slice)
1. **Carry-in-mouth** (the fish) — the one new mechanic. **[NEW]**
2. **Home interior** + wake/sleep integrated with the loop; carry survives the doorway. **[NEW/WIRE]**
3. **Town blockout** + navigation; player spawn beside the friend. **[WIRE]**
4. **Place NPCs + props**; CharacterProfiles + stub lines. **[WIRE/CONTENT]**
5. **Rewrite `scene6_flow`** to the tour (objectives, phase ticks, sleep, reveal). **[NEW]**
6. **Day-1 phase presets + fog/mood + window glows.** **[WIRE/ART]**
7. **Dock office / desk-jump**; the same-dawn reveal flags. **[NEW/WIRE]**
8. **Objective/hint surfacing**; audio ambience + fade stingers. **[NEW/ART]**
9. **Cut the ball; reconcile the crate; swap placeholder James.** **[WIRE]**
10. **Playtest to §12; iterate on pacing.**

## Already built (from the earlier greybox pass — reuse)
`ScreenFade`; `World.advance_time_phase/set_time_phase/time_phase/end_day` + `start_faded`/
`day_fade_time`; `DayNightCycle.set_phase/phase_count/current_phase`; `friend_cat`
`start_asleep`/`gated_sleep`/`enable_sleep`/`curled_up`/`stood_up`; `crate_goal_tile`/
`spawn_ball_goal`; `max_mount_step` (crate push fix); the scene-6 grass perf work; and the
scene-6 wiring hooks (day/night on, `start_faded`, the `Flow` node).
