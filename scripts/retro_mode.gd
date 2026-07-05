extends Node
## OPTIONAL retro / PS1-style look. The game world renders into a low-resolution
## SubViewport (see game_root.gd) and is scaled up with hard-edged (nearest)
## filtering, so the 3D looks like crisp low-res pixels while menus and dialogue
## stay full resolution. Colours are palette-limited + dithered.
##
## `active` is toggled at runtime from the main menu; it applies on the next scene
## load. Set the initial value here (false = start in normal full-res).

## Runtime master switch for the whole retro look.
var active := true

## Shrink factor for the 3D render. Internal res = window_size / SHRINK
## (1920 wide at SHRINK 4 -> 480 wide). Bigger = chunkier. 3 or 4 is PS1-ish.
const SHRINK := 2
## Anti-aliasing on the low-res buffer: 0 = off, 1 = 2x, 2 = 4x, 3 = 8x. This
## smooths blade/edge stair-stepping WITHIN the pixel grid, which is the main cure
## for the moving-grass twinkle (it kills sub-pixel edge flicker). 4x is a good
## balance; higher = smoother but a touch softer. Try 3 (8x) if grass still shimmers.
const MSAA := 3
## Grass tuning while retro is on: fraction of blades kept, and fraction of wind
## sway kept (less motion = less shimmer). Visuals of each blade are unchanged.
const GRASS_DENSITY := 0.9
const GRASS_SWAY := 0.4
## Colour palette limiting: shades PER channel (lower = more banded/retro).
## 5 is roughly a 15-bit PS1-ish palette. Set high (e.g. 256) to disable.
const COLOR_LEVELS := 8
## Ordered (Bayer) dithering strength, 0 = off, 1 = full.
const DITHER := 0.1
