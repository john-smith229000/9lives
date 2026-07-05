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
