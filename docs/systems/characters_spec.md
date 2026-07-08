# Characters — Design Spec

Status: **v1 implemented.** Characters are defined once as reusable `CharacterProfile`
resources and looked up by id through the `Characters` autoload. Placeholders: **Bob**
is the placed villager in scene 1, **John** is the roaming NPC in scene 3 — both
share the current model for now.

Files: `scripts/character_profile.gd`, `scripts/characters.gd` (`Characters`
autoload), `characters/bob.tres`, `characters/john.tres`. Touched: `interactable.gd`,
`dialogue.gd` + `dialogue_box.gd` (voice blip), `interaction.gd`, `scene_flow.gd`
(`say_as`/`express`), `world.gd` + `npc_director.gd` (roamer profile), `npc.gd`
(freeze during dialogue), `scene1.tscn`, `scene3.tscn`.

## The split (who owns what)

- **Story / plot lines → the scene** (a `SceneFlow` beat, or an `Interactable`'s
  `lines`). These vary per scene and, later, per day.
- **A character's identity + personality → their `CharacterProfile`**: name, model,
  voice blip, walk speed, and an `expressions` library (greetings, reactions,
  catchphrases) usable from anywhere.

## CharacterProfile fields

`id` ("bob"), `display_name` ("Bob"), `model` (optional PackedScene — blank = use the
scene's existing model), `voice` (optional blip played while text types),
`walk_speed` (0 = default), `expressions` (Dictionary: `"greeting" -> "..."`, value
can be a String or an array of Strings). Blank fields fall back to shared defaults,
so characters can share everything now and diverge one field at a time.

## Adding / using a character

1. Duplicate `characters/bob.tres`, set a new `id`, `display_name`, and expressions.
   (It's auto-registered — `Characters` loads everything in `res://characters/`.)
2. **Placed character:** on an `Interactable`, set `profile` to the .tres. The box
   shows their name + plays their voice; the scene's `lines` are the story. To make a
   placed/roaming character just greet (no story lines), set `expression_key` (e.g.
   "greeting") and they'll speak that expression.
3. **Roaming character:** set the World's `npc_profile` (see scene 3). The
   `NpcDirector` spawns the NPC and attaches a greeting `Interactable` automatically.
4. **From a flow:** `await say_as("bob", ["Story line here."])` speaks flow-authored
   text under Bob's name/voice; `await express("bob", "scoff")` fires his own bark.
   `say_as`/`express` accept a profile, an id string, or a node with a `profile`.

## Voice blips

If a profile has a `voice` stream, the dialogue box plays it every couple of
characters while typing (Animal-Crossing style). Left blank = silent, so this is
inert until you add sound files — then just drop one on the profile's `voice`.

## Notes

- The roaming NPC now freezes (holds its pose) while any conversation is open, so you
  aren't talking to someone walking away.
- Deferred: `ask()` player choices (signature reserved in `SceneFlow`); a `GameState`
  (current_day + flags) so profiles/flows can branch expressions by story state;
  per-character unique animations (the `model`/anim override hook exists — wire when a
  character gets its own rig).
