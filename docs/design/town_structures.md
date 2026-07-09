# Town Structures — Catalog & Details

A world/art reference for every structure in the harbor town: what it is, what it's made of,
its condition, where it sits, and how it changes as the town heals. Companion to
`locations_and_interiors.md` (which covers *entering* buildings) — this doc is the physical
town. Roles only; town unnamed. The scene 6 mesh (`scene6ground/structures/water.glb`) is
the existing town; this informs art passes and where interactive pieces sit.

## 1. Geography & silhouette

The town is a **bowl around a harbor**. Read from the water inward and upward:

- **The water & harbor mouth** — a fogged basin with a narrow **mouth** between two
  breakwater arms; this is what the ship must thread, and can't, in the dark.
- **The waterfront** — the **big ship dock** (deep berth) on one arm, the **small marina /
  wharf** (shallow slips, boat cradles) on the other, joined by the **quay / sea wall**.
- **The lower town** — lanes climbing from the quay: the **fish stall**, the **café /
  bookshop**, the **general store**, packed **townhouse** terraces.
- **The square** — the inland crossroads: the **storm-struck tree**, a bench, a **harbor
  bell**.
- **The point** — above it all, on the cliff, the **lighthouse** and its **foot cottage**,
  reached by the **cliff path**. The dark lighthouse is the town's dominant silhouette, visible
  at the edge of almost every frame.
- **The edges** — cliff, **tidepools**, a **wooded strip**, and the player's **home cottage**
  tucked at the harbor's edge.

Composition rule: **the dark lighthouse is always somewhere in shot** — a constant,
unspoken reminder. When it finally lights (Day 8–9), the whole silhouette changes.

## 2. Materials & palette

- **Materials:** tarred clinker-built boats, weathered grey timber, salt-stained stone
  quays, slate roofs, rope, net, brass fittings gone green, painted signs faded to ghosts.
- **Palette:** muted and greyed — fog-blue, wet stone, bleached wood — with **one warm gold
  hour** in the afternoon and the small warm glows of windows at dusk. The sea reads
  *empty*: no ships, no bustle, gulls heard more than seen.
- **The condition motif:** almost everything is **shut, stalled, or piling up** — shutters
  closed, boats in cradles, empties stacked, paint peeling, the tower dark. This isn't
  ruin; it's **paused**. Which sets up the payoff:
- **Healing states:** key structures have a **broken → mended** look tied to a persistence
  flag (see §4), so the town **visibly recovers** as you fix things across loops — the one
  reward the loop can give.

## 3. Structure catalog

Each: **role · exterior/materials · details · condition & states · placement · enterable? ·
hooks.**

### The lighthouse tower
- **Role:** the spine — relight it and the ship can find the mouth. The town's landmark.
- **Exterior:** tall tapering stone tower, whitewash worn to grey, a brass-and-glass lantern
  room up top, an external stair/gallery.
- **Details:** a green-tarnished weathervane; a **missing brass lens fitting** (it's the one
  storm-lodged in the square's tree); scorch-free cold lamp; a keeper's key-hook by the door,
  empty.
- **Condition & states:** `beacon dark` (default) → `beacon_ready` (glass + oil + stair
  done, still unlit) → `beacon_lit` (the beam sweeps; the biggest single visual change in
  the game).
- **Placement:** the cliff point, above the town. **Enterable:** yes — tower interior
  (stairs → lantern room), locked until `has_tower_key`.
- **Hooks:** Day 7 assembly, Day 8 flame.

### The foot cottage (keeper's house / sickroom)
- **Role:** where the keeper tends their **sick partner**, alone; the **sickroom**.
- **Exterior:** low stone cottage hugging the tower base, one **always-lit window**
  (the bedside lamp) under all that dark, a washing line, a worn doorstep where the keeper
  steps out only briefly.
- **Details:** a chair worn smooth beside the bed; a **model boat / ship painting** just
  visible in the window (the partner was a sailor once).
- **Condition:** unchanging until the end — it's the one place already "kept," just small.
- **Placement:** at the tower's foot. **Enterable:** yes — doorway-gated until trust opens it.
- **Hooks:** the mirror; the trust chain; the tower key.

### Home — the player's cottage
- **Role:** the emotional anchor; wake/sleep bookend.
- **Exterior:** a small weatherboard cottage at the harbor's edge, a window you can see the
  friend's nest through, a crooked chimney, a mat by the door.
- **Details:** a shelf inside for the gifts you bring; the nearest thing to warmth in the
  frame.
- **Placement:** harbor edge, near the wharf (short first walk out). **Enterable:** yes.
- **Hooks:** the loop's start/end; fish delivery; the gift ritual.

### The café / bookshop
- **Role:** the clue hub; the town's memory.
- **Exterior:** a narrow shopfront, small-paned bay window fogged with warmth, a **door bell
  that no longer rings**, a swinging sign gone illegible, two chairs just visible inside.
- **Details:** a **barometer stuck on CHANGE** in the window; stacked crates of unsold books.
- **Condition:** dim and dusty; brightens slightly as the town returns (more light in the
  window late-game).
- **Placement:** a lower-town lane. **Enterable:** yes.
- **Hooks:** read-to-learn (beacon needs, ship/vet); the loop-sense thread.

### The general store / grocer
- **Role:** items — oil, the trap, dwindling supplies.
- **Exterior:** a plain shop with **half-empty window shelves**, a produce rack mostly bare,
  a side door to the **back storeroom**.
- **Details:** patched awning; a delivery ledger with nothing incoming; rat-gnawed sack in
  the corner.
- **Condition:** shelves visibly refill toward the end (a healing state).
- **Placement:** lower-town lane, near the square. **Enterable:** yes (front + storeroom,
  storeroom gated on returning the lost delivery).
- **Hooks:** trap + oil; the storm-stranded delivery quest.

### The fish market — stall + cold-store
- **Role:** fish (comfort + bait); the rats; tide/weather knowledge.
- **Exterior:** an open **stall under a striped, salt-faded awning** on the quay, slate
  slab, ice going to water, a chalk price-board wiped blank. Behind it, a small windowless
  **cold-store** shed.
- **Details:** gull-picked crates; a scale; yesterday's papers for wrapping.
- **Condition:** only scraps on the slab until the rats are dealt with → a proper catch
  after `rat_source_sealed` (a healing state you can *see* on the slab).
- **Placement:** on the quay. **Enterable:** no (stall is exterior; cold-store only peered
  into). **Hooks:** fish, rats, the ship schedule.

### The big ship dock — quay, berth & office
- **Role:** where the ship must tie up; the ship-seed (the register).
- **Exterior:** heavy timber-and-stone **deep-water berth**, iron **bollards**, a **crane /
  derrick** idle against the sky, a small stone **dock office**.
- **Details:** the berth **fouled by a sunk skiff / debris**; a chained gangway; a stopped
  clock in the office; tide charts.
- **Condition & states:** `berth fouled` → `berth_cleared` (debris gone, gangway down —
  the ship can dock). The derrick reactivates for the beacon haul.
- **Placement:** the dock arm of the harbor. **Enterable:** the office (tiny) — yes.
- **Hooks:** the berth puzzle (Day 6); the register clue.

### The marina / small wharf — slips, cradles & shed
- **Role:** small boats, the crate/barrel supply, the marina worker.
- **Exterior:** finger **slips** and a **boom-gate**, boats up in **cradles** gleaming with
  fresh varnish (ready, nowhere to sail), stacks of **fish-crate empties** and **barrels**,
  a **capstan/winch**, a **tool shed**.
- **Details:** coiled rope everywhere; an unlit lamp; a jammed slip full of empties (Day 2).
- **Condition & states:** `slip jammed` → `slip_cleared`; the cliff-gap **box-bridge** →
  `bridge_permanent` (a real plank).
- **Placement:** the marina arm, opposite the big dock. **Enterable:** the shed (optional).
- **Hooks:** crates/barrels source; the slip puzzle; the winch; the bridge.

### The harbor mouth — breakwaters & sea-gate
- **Role:** the threshold the ship must pass; a phase/tide feature.
- **Exterior:** two rubble-stone **breakwater arms** narrowing to a gap; a timber **sea-gate
  / sluice** with a **lever**; a channel that shoals at low tide.
- **Details:** a leaning channel marker; weed on the tide-line marking the levels.
- **Condition:** the mouth is passable once the **beacon** guides and the **berth** is clear
  (and any channel obstruction is cleared).
- **Placement:** seaward, framing the basin. **Enterable:** no. **Hooks:** tide puzzles;
  the sea-gate lever; the ship's final approach.

### The square — crossroads, storm tree & bell
- **Role:** the town's heart; a hub connecting the lanes.
- **Exterior:** cobbled open space, a big **storm-struck tree** (the **lens fitting** lodged
  high in it), a weathered **bench** (the retirees), a **harbor bell** on a post, a dry
  fountain or well.
- **Details:** a notice board of curled, out-of-date bills; leaf-litter no one clears.
- **Condition:** lifeless early, a few figures returning late-game.
- **Placement:** inland crossroads. **Enterable:** no.
- **Hooks:** the tree (lens, stack+jump); the bell (possible in-world rest/checkpoint point —
  see the checkpoint spec); retiree lore.

### Townhouses / residences
- **Role:** density, life, facades; a couple are functional (the retiree's cottage, doors
  that matter).
- **Exterior:** stacked **terraces** with **shuttered windows**, slate roofs, smoking-less
  chimneys, window-boxes gone to weed.
- **Details:** most doors **don't open** — so the few that do feel chosen.
- **Condition & states:** **shutters/lamps** are the town's clearest healing meter — closed
  and dark early, opening and glowing as fixes accumulate toward Day 9.
- **Placement:** the lower-town lanes. **Enterable:** select few only.

### Quay, sea wall & fixtures
- **Role:** the walkable waterfront edge + small kinetic set-dressing.
- **Exterior:** stone **sea wall**, iron **bollards** and **mooring rings** (buoys pulled in
  and stacked), ladders down to the water, **lobster/crab pots** piled unused.
- **Details:** the tide-line; a place to release the caught rat (the sea wall).
- **Placement:** rings the harbor. **Enterable:** no. **Hooks:** buoy/pot objects; rat
  release; edges the grid puzzles.

### Warehouses / storehouses
- **Role:** why goods pile up — the stalled trade made physical.
- **Exterior:** big **shuttered timber warehouses** along the dock, **empties stacked**
  outside because nothing ships out, a padlocked slider door.
- **Details:** faded cargo stencils; a cat-sized gap under a door (a shortcut?).
- **Placement:** behind the big dock. **Enterable:** no (maybe a gap-crawl shortcut).

### Cliff path & bridges
- **Role:** traversal to the lighthouse; where jump + box-bridge live.
- **Exterior:** a switchback **cliff path**, a **washed-out gap** (bridged with crates, then
  a permanent plank), a **ledge step** (the jump intro), a handrail long gone.
- **Condition & states:** the gap: `improvised box-bridge` → `bridge_permanent`.
- **Placement:** cliff, town → point. **Enterable:** no. **Hooks:** jump; box-bridge; the
  climb to the tower.

### Nature — tidepools, wooded strip, the cliff
- **Role:** quiet beats, texture, edges.
- **Exterior:** rock **tidepools** (exposed at low tide), a wind-bent **wooded strip**, the
  raw **cliff face**, grass and scrub (uses the existing grass system).
- **Details:** the friend's favourite tidepool spot; shells (gift items) on the strand at
  low tide.
- **Placement:** the town's edges. **Enterable:** no. **Hooks:** the evening quiet beat;
  low-tide gathering; gifts.

## 4. The town heals — visual state progression

Tie ambient structure states to persistence flags so progress is *seen*:

| Flag | Structure change |
|---|---|
| `slip_cleared` | the marina slip empties, boom swings free |
| `bridge_permanent` | box-bridge → a real plank on the cliff path |
| `rat_source_sealed` | fish stall's slab fills with a proper catch; a quiet market |
| `berth_cleared` | debris gone, gangway down at the big dock; derrick rigged |
| `beacon_ready` | glass + lamp visibly restored up top (still unlit) |
| `beacon_lit` | the beam sweeps; tower goes from black silhouette to living light |
| general progress | townhouse **shutters open + windows glow**; a few figures return; the café brightens; the grocer's shelves refill |

By Day 9 the same camera that opened on a shut, grey, empty town holds an open, lit, peopled
one — with the beam turning over it.

## 5. Notes for the modeler / level artist
- Keep the **dark lighthouse in most sightlines** (place it so lanes and the quay frame it).
- Author the **broken/mended variants** as swappable meshes/materials keyed to the flags in
  §4 (extends the persistence hooks in `gameplay.md`).
- Reserve clear **grid lanes** on the quay/wharf/square for the kinetic puzzles (barrels roll
  in straight lines — they need unobstructed runs and stopper walls).
- Doors: model most as sealed; give the **enterable** few a real threshold + doorway trigger
  volume (see `locations_and_interiors.md`).
- The **gold hour** and **window glows** are the main warmth against the grey — light them
  deliberately.

## Open questions
- Is the harbor obstruction the **berth** (debris) only, or also a **channel/sea-gate** at
  the mouth (two separate "let the ship in" fixes)? — affects the map and Day 6/late pacing.
- The **bell** as an in-world checkpoint/rest point — worth it, or keep checkpoints as UI?
- Warehouse **gap-crawl** shortcut — build a crawl mechanic, or cut?
- How literal should the **healing meter** be (subtle set-dressing vs. obvious before/after)?
