class_name DayPhase
extends Resource
## One preset in the day/night cycle. World tweens the sun and environment
## between these when time advances. Edit these in the inspector to tune the look.

## Just a label for the inspector.
@export var label := "Phase"
## Sun angle as Euler degrees (pitch, yaw, roll). Lower pitch = lower/longer sun.
@export var sun_rotation := Vector3(-50, -55, 0)
## Sun brightness and colour.
@export var sun_energy := 0.85
@export var sun_color := Color(1, 1, 1)
## Environment fill light (tints the shadows) and its strength.
@export var ambient_color := Color(0.7, 0.78, 0.85)
@export var ambient_energy := 0.55
## Flat sky / background colour.
@export var sky_color := Color(0.45, 0.62, 0.85)
## Snap the sun's compass angle (yaw) to this phase instantly at the start of the
## transition INTO it, instead of sweeping. Use for sunrise so the sun rises in
## place on this side rather than swinging all the way around (it's dark anyway).
@export var snap_yaw_on_enter := false
