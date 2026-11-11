extends "res://Shared/TrainingCore.gd"

# Original per-skill algorithms; shared animation/audio/fixture scheduling is in TrainingCore.gd.

func request_wanjian_cast() -> bool:
    WANJIAN_SWORD=load("res://"+world.spec.texture_paths.sword)
    if state!="idle" or world.overview or not wanjian_pending.is_empty(): return false
    state="wanjian_casting"
    play_action("suodi")
    sfx.play("wanjian_gather")
    wanjian_center=actor.global_position
    wanjian_direction={"north":Vector2.UP,"south":Vector2.DOWN,"east":Vector2.RIGHT,"west":Vector2.LEFT}[actor.facing]
    wanjian_elapsed=0
    wanjian_launch_clock=0
    wanjian_launched=0
    for i in range(WANJIAN_COUNT):
        var sword:=Sprite2D.new()
        sword.texture=WANJIAN_SWORD
        sword.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        sword.z_index=5
        sword.modulate.a=0
        world.add_child(sword)
        wanjian_pending.append(sword)
        var tween:=sword.create_tween()
        tween.tween_property(sword,"modulate:a",1.0,0.25+i*0.009)
        position_wanjian_sword(sword,i)
    status.text="Forming %d swords" % WANJIAN_COUNT
    return true




func position_wanjian_sword(sword: Sprite2D, index: int) -> void:
    var ring:=int(index/12)
    var angle:=TAU*float(index%12)/12.0+float(ring)*0.17+wanjian_elapsed*0.35
    var ground:=wanjian_center+Vector2.from_angle(angle)*(70+ring*40)
    sword.global_position=(ground+Vector2(0,-55)).round()
    sword.rotation=wanjian_direction.angle()+PI/2.0




func launch_wanjian_sword() -> void:
    var sword: Sprite2D=wanjian_pending.pop_front()
    var ground: Vector2=sword.global_position-Vector2(0,-55)
    var side:=Vector2(-wanjian_direction.y,wanjian_direction.x)
    var aim:=wanjian_center+wanjian_direction*560+side*float((wanjian_launched%9)-4)*18
    var velocity: Vector2=(aim-ground).normalized()*690
    sword.rotation=velocity.angle()+PI/2.0
    projectiles.append({"sprite":sword,"ground":ground,"velocity":velocity,"life":1.35,"damage":20})
    sfx.play("wanjian_launch",1.0+sin(float(wanjian_launched)*1.7)*0.07)
    wanjian_launched+=1
    if wanjian_pending.is_empty():
        state="idle"
        restore_locomotion()
        status.text="Launched %d swords" % wanjian_launched




func clear_wanjian() -> void:
    for sword in wanjian_pending:
        if is_instance_valid(sword): sword.queue_free()
    wanjian_pending.clear()
    wanjian_launch_clock=0
