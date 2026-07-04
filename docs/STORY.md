# 9 Lives — Story & Design Bible (working draft)

> This is a living doc. Anything marked **(choose)** or **TODO** is open. The point
> is that once the 9-day arc is nailed down, the **save/persistence list** at the
> bottom just falls out of it — the story is the spec for the systems.

---

## 1. Premise

Your dearest friend — a grey-and-white cat, **[FRIEND NAME]** — is sick, and
getting worse. There's no one in the little harbor town of **[TOWN NAME]** who can
help; the nearest help only comes by sea. The one hope is the **[SHIP NAME]**, due
to dock *tomorrow*, carrying **[a traveling vet / the medicine / a specialist]
(choose)** — though early on you may not even know that yet; part of the first days
is realizing the ship is your only chance.

You're an orange cat, and you love your friend more than anything. You are terrified
of losing them. Each night you curl up beside them to sleep — and wake at the *same*
dawn, the only soul who remembers the day before. You don't understand it, but your
desperation to save your friend has quietly **frozen time itself**: until you find a
real way to help them, tomorrow will never come. *(The "why" stays a mystery — it's
love and fear, never fully explained.)*

So the **why** is: save your friend. The **how** is: help arrives by ship. The
**obstacle** is: the ship can't dock. Everything else in the game is in service of
that.

### Why the ship can't dock (the puzzle spine)

The harbor **beacon (the lighthouse) never lights**, so at nightfall the ship can't
find the harbor mouth in the fog and turns back out to sea. The light is dark
because of a **chain of small broken things across town** — the keeper has stopped
tending it (grief? illness? gave up? **(choose)**), and the mechanism/fuel/lens/
stairs are variously broken or blocked. Relighting it is never one action; it takes
untangling the townsfolk's problems one repeating day at a time, and each thing you
mend *stays* mended into the next loop. Getting the beacon lit = getting the ship in
= getting your friend help.

### Number of days

**Nine** days/loops (matches the title, *9 Lives*). The reset here isn't "lives
spent" — it's the emotional time-freeze above — but nine is a good arc length and
the title still resonates.

### Alternate obstacle (if the lighthouse doesn't grab you)

- **Blocked harbor mouth** — a sunken boat / jammed sea-gate / debris; you open the
  channel over several days instead of (or as well as) lighting the beacon.

### Tone & telling

Understated. Most of the story is **implied**, not spelled out — the cat never
narrates the time-loop's cause, the keeper's situation is read through subtext, and
that the ship carries help for the keeper's loved one too is **implied, never
stated**. The keeper is openly **pessimistic** it will make any difference, which
quietly contrasts the player's refusal to give up. Let players infer; leave room.

---

## 2. The loop rules (how a "day" works)

- **The day ends when you sleep beside your friend.** Once the day winds into
  evening/night, you return to your friend and curl up next to them — that closes
  the loop, and you wake at the same dawn. It's the emotional heartbeat of the game.
- **Night is a *phase*, not a clock.** The day advances through phases
  (morning → evening → night) as you make progress / choose to head home, never on a
  real-time timer. No "be somewhere at 3:00." *(This repurposes the day/night cycle
  already built — it becomes gameplay, not just a test toggle.)*
- **Only the cat remembers.** Knowledge always carries across loops.
- **The town resets each day** to its day-N arrangement (routines, moveable objects,
  NPC positions) — *except* for the things the story says should stay changed.
- **Some progress persists** (see §6): repairs you've made, key items you hold, and
  relationship/story flags. This is what makes fetch quests and "I mended this for
  good" possible. **(choose how generous to be — see §6.)**

---

## 3. Setting & map

One persistent island/harbor-town map. Locations (all TODO to place):

- **Harbor + wharf** — where the ship will dock; the emotional focal point.
- **Marina** — fishing boats, ropes, crates; cozy clutter and puzzle props.
- **Lighthouse** — the beacon; the "engine" of the ending (if using the recommended
  mystery). The keeper lives here.
- **Fish market** — the fishmonger; knows tides/weather; morning bustle.
- **Bookstore / coffee shop** — the lore & clue hub; where the cat pieces the
  mystery together. A bookish, watchful character.
- **Restaurant** — the cook; feeds the town; a daily routine that can gate things.
- **Houses** — residents with small problems (the fetch-quest surface area).
- **Nature / terrain** — cliffs, tidepools, a path up to the lighthouse, a wooded
  edge. Uses the smooth terrain + grass you've already built.

---

## 4. Characters

- **The Player — orange cat.** Remembers the loop. Name: **[TODO]**.
- **The Friend — grey-and-white cat, sick.** The heart of the stakes; waiting for
  the ship. Name: **[TODO]**. *(Design note: worsening can be cosmetic/dialogue for
  tension without punishing the player mechanically — decide in §6.)*
- **Lighthouse keeper** — the thematic mirror of the player: they've stopped tending
  the beacon because they're **caretaking their own sick loved one** and can't leave
  their side to climb the tower. Their despair (given up on help coming) rhymes with
  the player's desperation (refusing to give up). The player relighting the light is
  the player doing for the keeper what they wish someone would do for them — and
  because the ship's help saves *both* sick friends, easing the keeper's burden and
  lighting the beacon are the same act. **How the player gets the light lit is open
  (choose):** (a) earn the keeper's trust/key by helping care for their loved one,
  then climb and light it yourself (after the repair chain); (b) free the keeper up
  so *they* can do it; (c) both — gain access via the keeper's arc, then fix + light
  it through the town's repair chain. Keeper's loved one: **[TODO — person? another
  cat? a child who'd normally have sailed out?]**
- **Fishmonger** — tides/weather knowledge; a clue or key item source.
- **Bookseller / barista** — the town's memory; helps the cat connect the dots.
- **Cook** — routines; feeds people; a schedule-based (but trigger, not clock) gate.
- **2–4 townsfolk in the houses** — each a small problem that's one link in the
  chain. **[TODO: sketch each]**

---

## 5. The 9-day arc (skeleton — fill the puzzles in)

Recommended shape: establish → unravel → fix the chain → the ship. Each mid-game day
should teach or use one mechanic and end with a **persistent change**.

- **Day 1 — The normal day.** A gentle day: your friend is unwell, you sense the
  town is your only help, evening comes, you go home and sleep beside them. Wake to
  the *same* dawn → the dawning realization you're looping. (Movement/interaction
  tutorial + establishes the sleep-to-end-day beat.) *Persists:* just your memory.
- **Day 2 — Confusion & searching.** You're sure now you're looping. You scour the
  town for anything that could help your friend and keep hitting dead ends (no vet,
  no cure here). First real puzzle + first permanent fix. Meet the lighthouse keeper
  and their sick loved one.
- **Day 3 — The hint.** A clue surfaces that *the ship* is the answer — e.g. the
  harbormaster/bookseller mentions the vet-or-medicine it carries, or the keeper lets
  slip they've been waiting on it too. Not yet spelled out.
- **Day 4 — The goal crystallizes.** It's now clear: your friend's only hope is the
  ship, and the ship can't dock because the beacon is dark, and the beacon is dark
  because the keeper can't leave their loved one. The real objective locks in.
- **Days 4–7 — The chain.** Each day, resolve one townsperson's problem that removes
  one obstacle between the town and a lit beacon (gain the keeper's trust, fix the
  mechanism/fuel/stairs, clear the way). Introduce mechanics gradually (crate
  bridges → pressure plates → fetch-and-keep → combined). Each day grants a
  **persistent unlock or key item**. **[TODO: one line per day.]**
- **Day 8 — The turn.** The beacon *almost* works; one last piece, and the emotional
  beat: you (and the keeper) choose to hope — to let tomorrow come, knowing it means
  time resumes and your friend is truly at risk again, trusting the ship will be there.
- **Day 9 — The ship comes in.** With everything mended, the light holds, the fog
  parts, the ship docks. Loop breaks; the friend is helped. Resolution. **[TODO]**

---

## 6. Persistent state (the save system — grows as the arc firms up)

Everything here is decided by the story beats above. Fill it in as days lock.

**Always persists:** player knowledge (implicit — it's the premise).

**Persists (physical progress) — candidates:**
- `current_day` (1–9)
- repaired/unlocked infrastructure flags — e.g. `lighthouse_stairs_fixed`,
  `harbor_channel_cleared`, `beacon_relit` **[TODO as designed]**
- key items held — e.g. `has_lantern`, `has_keeper_key` **[TODO]**
- relationship/story flags — e.g. `fishmonger_trusts_you` **[TODO]**

**Resets every day (rebuilt from `current_day` + the flags above):**
- NPC positions & daily routines
- moveable puzzle objects (crates, balls) back to their day-start spots
- any single-day puzzle state
- **(choose)** the friend's condition — cosmetic worsening vs. static

---

## 7. Open questions to resolve next

Resolved: core conflict (save the sick friend), the loop cause (unexplained
emotional time-freeze), the day-end trigger (sleep beside the friend), and the
puzzle spine (light the beacon so the ship can dock).

Still open:

- **What's aboard the ship**, exactly (traveling vet / medicine / specialist), and
  when does the cat *learn* the ship is the hope — day 1, or a day-2 discovery?
- **Why did the lighthouse keeper stop** tending the light?
- **Names:** town, ship, the two cats, the townsfolk.
- **Does any physical progress persist**, or is it knowledge-only until day 9? Still
  the biggest system-shaping choice (§2/§6). *Note: fetch quests + "I mended this"
  lean toward persistence.*
- **The ending's tone** — does the friend clearly recover, and does the cat ever
  understand what it did? (Worth deciding early; it colors everything.)
