# Xuanxiao Cast — standalone native 1x playback

Open project.godot in Godot 4. Space casts; A toggles auto playback. Top row: formal Idle reference; bottom: current Idle/Cast/recovery. A fixed line marks the foot anchor. All PNGs in PNG/ are byte-identical copies from this product's character source, included here for portability, not additional designs.

actor.json defines frame durations, loop flags and per-direction anchors. Cast is 8 frames / 1200ms, non-looping; it returns to the formal Idle at the same world foot position. Changing canvas sizes must change the texture offset with the clip. Do not center or scale the character by its canvas.

The cast_release(direction) signal fires once for each cast direction: north at 260ms (frame 2), other directions at 720ms (frame 5). These are visual integration suggestions, not API-authored damage events or a complete skill system. Pick actual VFX/hit timing per skill. Inputs while casting are ignored.

命令行测试 / Test: Godot --headless --path . --script res://Validate.gd

Production frames and the full animation library live in the product root's Characters/ folder: see the product's Characters/XUANXIAO_CAST.md. This small project does not modify the town Demo, attack sets, or other actors.
