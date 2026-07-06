extends Node
## Central "timing profile": one place for the presets that used to be scattered
## across dialogue_box.gd, iso_camera.gd and world.gd. Dialogue, the camera and the
## SceneFlow sequencer all read from here, so tuning the game's overall feel (text
## speed, camera pans, standard pauses) is a single-file job. Flows can still pass
## per-beat overrides where a moment needs something special.
##
## Registered as the "Timing" autoload.

# --- Dialogue -------------------------------------------------------------
## Speech typewriter speed (characters per second).
var text_cps := 26.0
## Hint-banner typewriter speed (calmer than speech).
var hint_cps := 15.0
## Seconds for the hint banner to fade in.
var hint_fade := 1.0

# --- Camera ---------------------------------------------------------------
## Smoothing while panning to / from a spotlight target (lower = slower pan).
var camera_pan_smooth := 1.5
## Default cinematic beats: hold on the subject, then hold on the focus target.
var camera_pre_hold := 2.5
var camera_hold := 4.0

# --- Sequencer defaults ---------------------------------------------------
## Default wait() used by flows when no time is given.
var default_wait := 2.5
## Speed a scripted NPC walks at during move_npc().
var npc_walk_speed := 1.6

# --- Attention arrow ------------------------------------------------------
var arrow_delay := 1.0        # wait before it appears
var arrow_height := 1.8       # local Y above the NPC
var arrow_scale := 1.0
var arrow_bob_amp := 0.15
var arrow_bob_speed := 3.0

# --- Highlight outline ----------------------------------------------------
var outline_color := Color(1.0, 0.92, 0.25)
var outline_scale := 1.06
var outline_pulse_min := 0.60
var outline_pulse_period := 2.5
## Hovered-character outline: its own (usually thinner) thickness, and steady (no
## pulse) — separate from the prop outline above.
var char_outline_scale := 1.02

# --- Click-to-interact ----------------------------------------------------
## After clicking an NPC and walking up to them, wait this long before the
## conversation starts.
var interact_walk_delay := 0.5
## Mouse-hover pickup size for NPCs, as a fraction of the viewport height (the
## radius of the "you're hovering this character" bubble around their body).
var interact_hover_radius := 0.09
## World height above an NPC's feet that the hover aims at (roughly mid-body).
var interact_hover_y := 0.9
## Seconds before a walking NPC can say its "bump into the cat" line again.
var bump_cooldown := 6.0
