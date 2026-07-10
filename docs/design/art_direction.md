# Art Direction — the sunny veneer

The look, and the single idea it serves. This supersedes the muted/greyed palette described in
`town_structures.md` §2 (see §9 — that section needs updating to match). Engine reality: Godot
4.6, **GL Compatibility** renderer.

---

## 1. The thesis: a decoy

**The world looks bright, warm, and beachy — and never lets on. The grief lives underneath, in
the writing, the characters, and small details you only understand on a second look. The gap
between how it looks and how it feels is the emotional engine.**

You see a sunny pastel harbor town and you don't suspect a thing. Then you talk to people, learn
who they are, watch your friend a little too closely — and the sadness seeps up through a surface
that stays cheerful the whole time. That contrast is the point. It's the Omori / A Short Hike /
Spiritfarer / To the Moon move: cute, warm art carrying a sad story hits *harder* than sad art
does, because the player lowers their guard.

This resolves the old tension in the bible. The art is **not** supposed to express the
melancholy — it's supposed to hide it. The environment's job is to stay innocent.

Touchstones (mood + the trick, not literal style):

- **Omori** — pastel innocence over darkness; the definitive "sunny surface, sad depths."
- **A Short Hike / Alba** — bright, cozy, low-poly island warmth done gorgeously.
- **Spiritfarer** — warm and colorful *about* death; grief carried by writing, not palette.
- **Animal Crossing** — how a consistently sunny town can quietly hold loneliness and time.
- **Untitled Goose Game / Sable** — flat, near-textureless low-poly reading as premium via
  palette, silhouette, and light rather than detail.

---

## 2. The one rule

**The visuals must never telegraph the sadness.** Consistently bright, warm, and pastel from
Day 1 to Day 9. No cooling down at the sad beats, no grey-out, no ominous shadows. If a frame
*looks* melancholy, it's wrong — the melancholy is supposed to ambush the player through story,
not be visible on the surface.

Two direct consequences (these reverse earlier notes):

- **The unlit lighthouse is not ominous.** It's just a charming tower you haven't thought about.
  Its "wrongness" is learned through dialogue, never shown as a dark, threatening silhouette.
  Keep it in the sunny palette like everything else.
- **No grey → warm "healing" arc.** The town doesn't go from drab to bright as you fix it,
  because it was never drab — that would put the grief on the surface. The end-game payoff is
  *additive joy* (the beam sweeping, the ship's horn, people back on the quay, a warmer gold
  hour), not a world finally gaining color it was missing.

---

## 3. Hiding grief in plain sight (the core craft)

The environment art's real job is to plant the sad details inside cheerful framing, so they read
as innocent until the player knows better. Same frame, two meanings:

| What it looks like (first pass) | What it means (once you know) |
|---|---|
| The café's cozy two cups and two chairs | one cup is always cold; she pours for someone who isn't coming |
| The friend napping in a warm sunbeam | you're supposed to watch the ear — it stays up so you'll go |
| A quiet, peaceful afternoon town, few people out | a withering town holding its breath; empty chairs, shuttered windows |
| Boats gleaming with fresh varnish in their cradles | ready, with nowhere to sail |
| A charming lamp glowing in a window | the mother's lamp, lit every night for someone the sea took |
| A pretty unlit lighthouse on the point | the reason nothing can reach the town |

Author these as *set dressing that's cute by default.* The player should be able to walk past all
of it and feel only warmth on Day 1 — and feel the floor drop out on a re-read. Keep the
compositions genuinely pleasant; let the writing supply the knife.

---

## 4. Palette — beachy pastel (starting values, tune in-engine)

Pull saturation **down** from the current candy build, but keep everything **bright and airy**
(low saturation, high value — sun-faded, not neon, not dark).

**World base (warm, soft, sunlit):**

- Sky: soft warm blue `#AFD3E2` → near-white warm haze at the horizon `#EAF1EC`
- Sea: gentle turquoise/aqua `#7FC8C4` shallows → `#4F9EA8` deeper (soft, not tropical-electric)
- Sand / stone / paths: warm sandy neutrals `#E4D4B8`, `#CDB79A`
- Grass: soft sage / celadon `#A7C08A`, `#8FAE79` (mute the vivid lime hard)
- Timber / boardwalk: sun-bleached warm wood `#D8C4A0`, `#B79E78`

**Buildings (chalky pastels — vary hue, keep sat low, value high):**

- Chalky coral `#E9A79A`, buttery cream `#F3E4C1`, powder blue `#BFD6E0`,
  dusty seafoam `#B7D6C4`, faded terracotta roof `#D08C6E`, soft rose `#E7C4C4`

**Warm accents (lamps, gold hour, the eventual beacon):**

- Window / lamp glow: `#FBD98C` → `#F4B85E`
- Beacon lit (endgame payoff): `#FFE9B0` core with a soft warm bloom — the biggest single burst
  of warmth in the game, saved for last.

**Lighthouse:** sun-worn coral-and-cream, faded and friendly — not a fire-engine candy stripe,
but not grey either. It should look like a postcard, not a warning.

General discipline: it's the *saturation* that's too high right now, not the brightness. Chalk
everything down a notch; keep it luminous.

---

## 5. Light & atmosphere

On GL Compatibility you have no SSAO/SSR/SDFGI, so the look lives in the WorldEnvironment,
the directional light, and a post-process grade — which is ideal for this style.

- **Bright, soft, diffuse sunlight.** A warm key light, gentle soft shadows (baked where you can),
  an airy fill. Think mid-morning-to-afternoon beach light, consistently.
- **Light sea-haze, not fog.** A *pale, warm* atmospheric haze for depth and prettiness — softens
  distant geometry, adds that hazy-summer feel. Airy and inviting, never gloomy or closing-in.
  (Distinct from the gloom-fog the old bible wanted.)
- **Golden hour as beauty, not melancholy.** A lovely warm end-of-day wash is on-brand — just
  frame it as *gorgeous*, not sad. Windows glow warm at dusk because the town is cozy, not because
  it's grieving.
- **Color grade toward airy + warm.** Lift shadows (no crushed blacks), slightly desaturate to
  pull the current candy toward chalky pastel, warm the overall balance, soft bloom on the
  highlights. Routed through the full-screen post layer you already have (`retro_post` proves the
  pipeline exists). This single grade will unify mismatched placeholder assets fast.
- **Day-phase = a gentle warm arc**, not a mood swing: soft morning → bright noon → gold
  afternoon → warm cozy dusk with window lamps. Never a cold or dark phase that gives the game
  away.

---

## 6. Water & sky

- **Water:** your shader (`water_painterly.gdshader`) is already close to right for beachy — it
  was built for a Wind Waker / Mario Sunshine bay. Just soften it: ease the shallows toward the
  gentle turquoise above, keep the caustic web light and playful, keep the foam friendly. This is
  the one system that was already pointed the right way; lean into it.
- **Sky:** soft warm blue with a pale hazy horizon so sea and sky melt together prettily. A few
  soft clouds. Save the most saturated blue-and-gold sky for the gold hour and the Day 9 payoff.

---

## 7. Characters

- **Style:** simple, flat-shaded, readable from iso distance via silhouette + one clear color
  each. (`npc1` ships PBR metallic/roughness/normal maps — wasted on this renderer and style;
  go flat/vertex-colored, it's cheaper and more cohesive.)
- **The two cats:** the **orange cat** is a warm, friendly pop against the pastels — cheerful, not
  ember-against-grey (that framing belonged to the gloom version). The **grey-and-white friend**
  stays soft and low-contrast — reads as a sweet sleepy cat, *not* visibly fading. The decline is
  animation and behavior, never a sickly recolor.
- **Townsfolk:** soft pastel clothing, each with one signature hue for role readability. Everyone
  looks pleasant and approachable — the sadness is in what they *say*, not how they look.
- **Spend art budget on animation tells, not model detail.** The friend's ear (up → down), eating
  → refusing, poses — that's where the grief is delivered (see `friend_cat` leak-state in
  `gaps.md`). Innocent-looking cat, devastating behavior.

---

## 8. Where the grief actually lives (so the art doesn't have to)

Since the visuals stay sunny, these carry the weight — budget accordingly:

- **Writing / dialogue** — the primary narrator (per `throughlines.md` §8, feelings implicit).
- **Character animation** — the ear, the untouched fish, barely stirring.
- **Music** — a warm, simple theme with a wistful undertow; let the *score* be a half-step sadder
  than the picture. This is the safest place to leak the truth.
- **Sound design** — the absent horn (the game's defining silence) → the horn on Day 9.
- **Environmental storytelling** — the §3 "plain sight" details, cute until understood.

---

## 9. Doc conflict to fix

`town_structures.md` §2 currently specifies the *opposite* palette ("muted and greyed — fog-blue,
wet stone, bleached wood… the sea reads empty") and `throughlines.md` §2/§8 treats the visuals as
the melancholy narrator (dark lighthouse in every frame, mood carries the grief). Under the
sunny-veneer thesis those are now wrong and will misdirect future art work. **Recommend
rewriting `town_structures.md` §2 to the pastel palette above, and adding a line to
`throughlines.md` that the *visuals are a decoy* — grief is carried by writing/animation/music,
not by mood-lighting.** (Offered — not done yet, since those are your core bible docs.)

---

## 10. Retro mode

`retro_post` + `RetroMode` (PS1 Bayer dither) is a distinct third identity. Keep it as an
**optional toggle / novelty / photo filter**, not the game's look — unless you deliberately want a
lo-fi pastel game (still possible, still needs §4's palette). Don't let it be a silent influence.

---

## 11. Technical constraints (they help)

Godot 4.6, `gl_compatibility`, MSAA 2x, 720p base. No PBR-heavy pipeline / no screen-space
effects — which pushes you toward flat-shaded surfaces, baked lighting (you already have
`scene6structures_lighthouse_baked.png`), light haze, and a post grade. That's exactly the toolkit
a bright stylized pastel game wants. Keep effects in the full-screen post layer; it's your
cheapest, highest-leverage control and it unifies everything.

---

## 12. Next steps (fastest impact first)

1. **Proof-of-veneer pass on the current scene, no remodeling:** desaturate ~25–35%, warm the
   grade, lift shadows, add soft bloom + light warm haze, keep it bright. See the candy build turn
   into sun-faded pastel in an evening.
2. **Soften the water** (§6) — a few uniform tweaks toward gentle turquoise.
3. **Recolor the loud offenders:** grass → sage, houses → chalky pastels, lighthouse →
   coral-and-cream, orange cat → warm friendly pop.
4. **Author the gentle warm day-phase arc** (§5) — no cold phases.
5. **Reconcile the bible** (§9) so the docs stop pulling toward gloom.
6. **Then** modeling/detailing, and the §3 "plain sight" set-dressing that pays off on re-read.

Do #1 first — everything downstream is easier to judge once the veneer is on top of what you have.

---

## 13. One line

Bright, warm, beachy pastel that never once looks sad — a sunny veneer the player doesn't
suspect, with all the grief carried by writing, animation, and music underneath. Chalk the current
candy palette down (saturation, not brightness), keep the whole game consistently cheerful, and
let the story — not the light — break the player's heart.
