extends Node2D

var world: Node2D
var actor: CharacterBody2D
var config: Dictionary
var effect_frames: SpriteFrames
var dummies: Array[Node2D]=[]
var projectiles: Array[Dictionary]=[]
var transient_effects: Array[AnimatedSprite2D]=[]
var state: String="idle"
var mode: String="slash"
var emitted: bool=false
var attack_direction:=Vector2.UP
var buff_remaining:=0.0
var ghost_clock:=0.0
var ghosts: Array[Sprite2D]=[]
var wanjian_pending: Array[Sprite2D]=[]
var wanjian_center:=Vector2.ZERO
var wanjian_direction:=Vector2.UP
var wanjian_elapsed:=0.0
var wanjian_launch_clock:=0.0
var wanjian_launched:=0
var four_skills: Node2D
var sfx: Node
var status: Label
var action_buttons: Array[Button]=[]
var total_hits: int=0
var moying_charge_time:=0.0
var moying_release_requested:=false
var emissions: int=0
var wall_stops: int=0
const SPAWN=Vector2(1536,1210)
const SUODI_DURATION=10.0
const SUODI_SPEED=2.0
const WANJIAN_COUNT=36
const WANJIAN_INTERVAL=0.055
var WANJIAN_SWORD:Texture2D


func _ready() -> void:
    actor=world.player
    config=JSON.parse_string(FileAccess.get_file_as_string("res://Shared/actions.json"))
    var clips: SpriteFrames=actor.animated_sprite.sprite_frames
    for clip in config["actions"]:
        clips.add_animation(clip)
        clips.set_animation_speed(clip,8)
        clips.set_animation_loop(clip,false)
        for file in config["actions"][clip]: clips.add_frame(clip,load("res://"+file))
    effect_frames=SpriteFrames.new()
    effect_frames.remove_animation("default")
    config["effects"]=world.spec.get("effects",{})
    for clip in config["effects"]:
        effect_frames.add_animation(clip)
        effect_frames.set_animation_speed(clip,8)
        effect_frames.set_animation_loop(clip,clip=="projectile")
        for file in config["effects"][clip]: effect_frames.add_frame(clip,load("res://"+file))
    for object in world.entities.get_children():
        if object.get_meta("asset_id","")=="training_wood_dummy":
            dummies.append(object)
            object.set_meta("training_origin",object.position)
            object.set_meta("training_hp",300)
            object.set_meta("training_hits",0)
            var label:=Label.new()
            label.position=Vector2(-45,-148)
            label.size=Vector2(90,44)
            label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            label.add_theme_font_override("font",ThemeDB.fallback_font)
            label.add_theme_font_size_override("font_size",14)
            label.add_theme_color_override("font_color",Color("e8d9b3"))
            label.add_theme_color_override("font_outline_color",Color("242420"))
            label.add_theme_constant_override("outline_size",3)
            object.add_child(label)
            object.set_meta("training_label",label)
            update_dummy(object)
    assert(dummies.size()==3)
    actor.animated_sprite.frame_changed.connect(on_action_frame)
    actor.animated_sprite.animation_finished.connect(on_action_finished)
    sfx=Node.new()
    sfx.set_script(load("res://Shared/SkillAudio.gd"))
    add_child(sfx)
    four_skills=Node2D.new()
    four_skills.set_script(load("res://"+world.spec.source) if world.skill_id in ["zanghua","rulai","taiji","moying"] else load("res://Shared/EmptyEffect.gd"))
    four_skills.training=self
    add_child(four_skills)
    build_panel()
    reset_yard()


func build_panel() -> void:
 var layer:=CanvasLayer.new()
 layer.layer=15
 add_child(layer)
 var panel:=PanelContainer.new()
 panel.position=Vector2(18,18)
 panel.custom_minimum_size=Vector2(790,128)
 layer.add_child(panel)
 var box:=VBoxContainer.new()
 panel.add_child(box)
 var picker:=OptionButton.new()
 box.add_child(picker)
 var items:Array=world.available
 for e in items:picker.add_item(e.name_en)
 picker.select(items.find(world.spec))
 picker.item_selected.connect(func(i:int):get_tree().change_scene_to_file("res://"+items[i].scene))
 var help:=Label.new()
 help.text="WASD / Arrows move | SPACE cast (hold for Ink) | H reset | J/K/L sword arc"
 box.add_child(help)
 var cast:=Button.new()
 cast.text="Cast / Replay (hold for Ink Slash)"
 cast.focus_mode=Control.FOCUS_NONE
 cast.button_down.connect(cast_selected)
 cast.button_up.connect(func():if world.skill_id=="moying":release_moying_charge())
 box.add_child(cast)
 status=Label.new()
 box.add_child(status)

func cast_selected() -> bool:
 if world.skill_id=="suodi":return request_suodi_cast()
 if world.skill_id=="wanjian":return request_wanjian_cast()
 if world.skill_id=="sword":return request_attack("combined")
 return request_four_skill(world.skill_id)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or event.echo:return
 if event.keycode==KEY_SPACE:
  if event.pressed:cast_selected()
  elif world.skill_id=="moying":release_moying_charge()
 elif event.pressed and event.keycode==KEY_H:reset_yard()
 elif event.pressed and world.skill_id=="sword" and event.keycode in [KEY_J,KEY_K,KEY_L]:request_attack({KEY_J:"slash",KEY_K:"projectile",KEY_L:"combined"}[event.keycode])
 else:return
 get_viewport().set_input_as_handled()


func cardinal() -> String:
    var vector:=Vector2.RIGHT.rotated(actor.DIRECTIONS.find(actor.facing)*PI/4.0)
    if absf(vector.x)>absf(vector.y)+0.001: return "east" if vector.x>0 else "west"
    return "south" if vector.y>0 else "north"


func play_action(kind: String) -> void:
    var direction:=cardinal()
    actor.facing=direction
    actor.velocity=Vector2.ZERO
    actor.set_physics_process(false)
    var anchor: Array=config["anchors"][kind][direction]
    actor.animated_sprite.position=-Vector2(anchor[0],anchor[1])
    actor.animated_sprite.play(kind+"_"+direction)
    actor.animated_sprite.set_frame_and_progress(0,0)


func request_attack(kind: String) -> bool:
    if state!="idle" or world.overview: return false
    state="attack"
    mode=kind
    emitted=false
    play_action("attack3")
    attack_direction={"north":Vector2.UP,"south":Vector2.DOWN,"east":Vector2.RIGHT,"west":Vector2.LEFT}[actor.facing]
    status.text="Attack: %s | Total hits: %d" % [kind,total_hits]
    return true


func request_suodi_cast() -> bool:
    if state!="idle" or world.overview: return false
    state="casting"
    play_action("suodi")
    sfx.play("suodi_cast")
    status.text="Ready / Cast with Space"
    return true


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


func request_four_skill(kind: String) -> bool:
    if state!="idle" or world.overview: return false
    state="four_cast"
    mode=kind
    emitted=false
    play_action("rulai" if kind=="rulai" else "attack3" if kind=="moying" else "suodi")
    var facing: Vector2={"north":Vector2.UP,"south":Vector2.DOWN,"east":Vector2.RIGHT,"west":Vector2.LEFT}[actor.facing]
    four_skills.start(kind,facing)
    if kind=="moying":
        state="moying_charging"
        moying_charge_time=0
        moying_release_requested=false
        actor.animated_sprite.set_frame_and_progress(2,0)
        actor.animated_sprite.pause()
    status.text={"zanghua":"Ready / Cast with Space","rulai":"Ready / Cast with Space","taiji":"Ready / Cast with Space","moying":"Ready / Cast with Space"}[kind]
    return true


func release_moying_charge() -> void:
    if state=="moying_charging": moying_release_requested=true


func finish_moying_charge() -> void:
    state="four_cast"
    actor.animated_sprite.play()
    status.text="Ink charge: %.1f sec" % moying_charge_time


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


func on_action_frame() -> void:
    if state=="four_cast" and mode=="moying" and not emitted and actor.animated_sprite.frame>=4:
        emitted=true
        four_skills.release_ink()
    if state!="attack" or emitted or actor.animated_sprite.frame<4: return
    emitted=true
    emissions+=1
    if mode in ["slash","combined"]:
        sfx.play("sword_slash")
        spawn_effect("slash",actor.global_position+Vector2(0,-55)+attack_direction*38,attack_direction.angle())
        for dummy in dummies:
            var delta: Vector2=dummy.global_position-actor.global_position
            if delta.length()<=112 and delta.normalized().dot(attack_direction)>0.45 and not blocked(actor.global_position,dummy):
                hit(dummy,35)
    if mode in ["projectile","combined"]:
        sfx.play("sword_wave")
        # Sweep from the actor, so spawning ahead cannot skip a thin wall.
        var ground: Vector2=actor.global_position
        var effect:=spawn_effect("projectile",ground+Vector2(0,-55),attack_direction.angle())
        projectiles.append({"sprite":effect,"ground":ground,"velocity":attack_direction*420,"life":1.7})


func blocked(origin: Vector2, target: Node2D) -> bool:
    # Projected wall-top guard shapes must not intercept ground-level attacks.
    var ray:=PhysicsRayQueryParameters2D.create(origin+Vector2(0,-5),target.global_position+Vector2(0,-5),1)
    ray.exclude=[actor.get_rid()]
    var result:=get_world_2d().direct_space_state.intersect_ray(ray)
    return not result.is_empty() and result["collider"]!=target


func on_action_finished() -> void:
    if state=="attack":
        state="idle"
        restore_locomotion()
    elif state=="casting":
        state="idle"
        buff_remaining=SUODI_DURATION
        ghost_clock=0
        actor.speed_multiplier=SUODI_SPEED
        restore_locomotion()
        status.text="Ready / Cast with Space"
    elif state=="wanjian_casting":
        state="wanjian_releasing"
        status.text="Ready / Cast with Space"
    elif state=="four_cast":
        state="idle"
        restore_locomotion()
        four_skills.cast_finished()
    elif state=="dying":
        state="dead"
        status.text="Ready / Cast with Space"


func restore_locomotion() -> void:
    actor.animated_sprite.position=-actor.animation_anchors[actor.facing]
    actor.animated_sprite.play("idle_"+actor.facing)
    actor.set_physics_process(true)


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


func _physics_process(delta: float) -> void:
    if state=="moying_charging":
        moying_charge_time=minf(3.0,moying_charge_time+delta)
        four_skills.update_ink_charge(moying_charge_time)
        status.text="Ink charge: %.1f sec" % moying_charge_time
        if moying_charge_time>=3.0 or (moying_release_requested and moying_charge_time>=1.0):
            finish_moying_charge()
    if state in ["wanjian_casting","wanjian_releasing"]:
        wanjian_elapsed+=delta
        for i in range(wanjian_pending.size()):
            position_wanjian_sword(wanjian_pending[i],wanjian_launched+i)
        if state=="wanjian_releasing":
            wanjian_launch_clock+=delta
            while wanjian_launch_clock>=WANJIAN_INTERVAL and not wanjian_pending.is_empty():
                wanjian_launch_clock-=WANJIAN_INTERVAL
                launch_wanjian_sword()
    if buff_remaining>0:
        buff_remaining=maxf(0,buff_remaining-delta)
        if buff_remaining==0:
            sfx.play("suodi_end")
            actor.speed_multiplier=1.0
            clear_ghosts()
            if state=="idle": status.text="Ready / Cast with Space"
        elif state=="idle":
            status.text="Swift Step: %.1f sec remaining | 2x speed" % buff_remaining
            if actor.get_real_velocity().length_squared()>900:
                ghost_clock-=delta
                if ghost_clock<=0:
                    spawn_ghost()
                    ghost_clock=0.08
    sfx.set_loop("suodi_wind",buff_remaining>0 and state=="idle" and actor.get_real_velocity().length_squared()>900)
    for i in range(projectiles.size()-1,-1,-1):
        var projectile: Dictionary=projectiles[i]
        var previous: Vector2=projectile["ground"]
        var next: Vector2=previous+projectile["velocity"]*delta
        var ray:=PhysicsRayQueryParameters2D.create(previous+Vector2(0,-5),next+Vector2(0,-5),1)
        ray.exclude=[actor.get_rid()]
        var result:=get_world_2d().direct_space_state.intersect_ray(ray)
        projectile["life"]-=delta
        if not result.is_empty():
            if result["collider"] in dummies: hit(result["collider"],projectile.get("damage",55))
            else: wall_stops+=1
        if not result.is_empty() or projectile["life"]<=0:
            projectile["sprite"].queue_free()
            projectiles.remove_at(i)
        else:
            projectile["ground"]=next
            projectile["sprite"].position=(next+Vector2(0,-55)).round()


func update_dummy(dummy: Node2D) -> void:
    var label: Label=dummy.get_meta("training_label")
    label.text="HP %d/300 | Hits %d" % [dummy.get_meta("training_hp"),dummy.get_meta("training_hits")]


func hit(dummy: Node2D, damage: int, play_impact: bool=true) -> void:
    if int(dummy.get_meta("training_hp"))<=0: return
    total_hits+=1
    dummy.set_meta("training_hits",int(dummy.get_meta("training_hits"))+1)
    dummy.set_meta("training_hp",maxi(0,int(dummy.get_meta("training_hp"))-damage))
    update_dummy(dummy)
    if play_impact:
        sfx.play("sword_hit")
        spawn_effect("impact",dummy.global_position+Vector2(0,-55))
    status.text="Hit: -%d | Total hits: %d" % [damage,total_hits]
    # shortcut: a stationary test target, not enemy AI or a full damage/equipment system.
    var label: Label=dummy.get_meta("training_label")
    label.modulate=Color(1,0.65,0.4)
    create_tween().tween_property(label,"modulate",Color.WHITE,0.25)


func die() -> void:
    if state!="idle": return
    sfx.stop_all()
    four_skills.clear()
    clear_wanjian()
    buff_remaining=0
    actor.speed_multiplier=1.0
    clear_ghosts()
    state="dying"
    play_action("death")
    status.text="Ready / Cast with Space"


func revive() -> void:
    if state not in ["dying","dead"]: return
    state="idle"
    restore_locomotion()
    status.text="Ready / Cast with Space"


func reset_yard() -> void:
    sfx.stop_all()
    four_skills.clear()
    clear_wanjian()
    for projectile in projectiles: projectile["sprite"].queue_free()
    projectiles.clear()
    for effect in transient_effects:
        if is_instance_valid(effect): effect.queue_free()
    transient_effects.clear()
    clear_ghosts()
    buff_remaining=0
    moying_charge_time=0
    moying_release_requested=false
    ghost_clock=0
    actor.speed_multiplier=1.0
    state="idle"
    actor.position=SPAWN
    actor.facing="north"
    actor.forced_direction=Vector2.ZERO
    restore_locomotion()
    world.overview=false
    world.camera.position=SPAWN+Vector2(0,-128)
    world.camera.force_update_scroll()
    for dummy in dummies:
        dummy.position=dummy.get_meta("training_origin",dummy.position)
        dummy.set_meta("training_hp",300)
        dummy.set_meta("training_hits",0)
        update_dummy(dummy)
    status.text="Ready / Cast with Space"
