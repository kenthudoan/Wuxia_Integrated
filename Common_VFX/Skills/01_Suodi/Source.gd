extends "res://Shared/TrainingCore.gd"

# Original per-skill algorithms; shared animation/audio/fixture scheduling is in TrainingCore.gd.

func request_suodi_cast() -> bool:
    if state!="idle" or world.overview: return false
    state="casting"
    play_action("suodi")
    sfx.play("suodi_cast")
    status.text="Casting Swift Step"
    return true




func spawn_ghost() -> void:
    var visual: AnimatedSprite2D=actor.animated_sprite
    var ghost:=Sprite2D.new()
    ghost.texture=visual.sprite_frames.get_frame_texture(visual.animation,visual.frame)
    ghost.centered=visual.centered
    ghost.flip_h=visual.flip_h
    ghost.flip_v=visual.flip_v
    ghost.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    ghost.modulate=Color(0.55,0.9,1.0,0.55)
    ghost.z_index=4
    world.add_child(ghost)
    ghost.global_position=visual.global_position.round()
    ghosts.append(ghost)
    var tween:=ghost.create_tween()
    tween.tween_property(ghost,"modulate",Color(0.55,0.9,1.0,0.0),0.35)
    tween.finished.connect(func(): ghosts.erase(ghost); ghost.queue_free())




func clear_ghosts() -> void:
    for ghost in ghosts:
        if is_instance_valid(ghost): ghost.queue_free()
    ghosts.clear()
