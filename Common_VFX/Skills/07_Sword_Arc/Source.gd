extends "res://Shared/TrainingCore.gd"

# Original per-skill algorithms; shared animation/audio/fixture scheduling is in TrainingCore.gd.

func request_attack(kind: String) -> bool:
    if state!="idle" or world.overview: return false
    state="attack"
    mode=kind
    emitted=false
    play_action("attack3")
    attack_direction={"north":Vector2.UP,"south":Vector2.DOWN,"east":Vector2.RIGHT,"west":Vector2.LEFT}[actor.facing]
    status.text="Attack: %s | Total hits: %d" % [kind,total_hits]
    return true




func spawn_effect(clip: String, at: Vector2, angle: float=0) -> AnimatedSprite2D:
    var effect:=AnimatedSprite2D.new()
    effect.sprite_frames=effect_frames
    effect.position=at
    effect.rotation=angle
    effect.z_index=4
    effect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    world.add_child(effect)
    effect.play(clip)
    if clip!="projectile":
        transient_effects.append(effect)
        effect.animation_finished.connect(func(): transient_effects.erase(effect); effect.queue_free(),CONNECT_ONE_SHOT)
    return effect
