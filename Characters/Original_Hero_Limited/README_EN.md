# Straw-hat Hero — straw-hat swordsman

One independently usable straw-hat swordsman character.

| Action | Directions | Frames/direction | FPS | PNGs |
|---|---:|---:|---:|---:|
| Idle | 8 | 5 | 6 | 40 |
| Walk | 8 | 9 | 10 | 72 |
| Attack (attack3) | 4 | 8 | 8 | 32 |
| Death | 4 | 8 | 8 | 32 |
| Swift/common cast | 4 | 8 | 8 | 32 |
| Palm cast | 4 | 8 | 8 | 32 |

32 directional clips, 240 PNGs, one design. There is **no separate Hurt animation**. This bonus is not counted as another complete five-action actor. Casting clips contain visual animation; game skill logic is supplied by your project.

CLIPS.json is the unified catalogue; paths are relative to this folder. Use per-clip canvas, anchor and FPS, native 1x scale and nearest sampling. Hold the last Death frame; return to Idle after non-looping Attack/Cast. Never resize all canvases or recenter every frame by its visible bounds. animation.json describes Idle/Walk playback.

The same actor is retained as a runtime dependency in ../../Common_VFX/project.godot and in map examples; those copies are not additional designs. Pack license: ../../Documentation/LICENSE.txt.
