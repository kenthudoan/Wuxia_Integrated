extends Node2D

var training: Node2D
var world: Node2D
var actor: CharacterBody2D
var textures: Dictionary={}
var visuals: Array[Node2D]=[]
var petals: Array[Dictionary]=[]
var bolts: Array[Dictionary]=[]
var ink_projectiles: Array[Dictionary]=[]
var kind: String=""
var phase: String=""
var center:=Vector2.ZERO
var direction:=Vector2.UP
var clock:=0.0
var phase_clock:=0.0
var aura_remaining:=0.0
var bolt_clock:=0.0
var taiji_disc: Sprite2D
var reflected_count:=0
var cast_flash: Sprite2D
var ink_charge: Sprite2D
var ink_power:=0.0
var ink_material: ShaderMaterial
var actor_original_material: Material

const PETAL_COUNT=96
const PETAL_RAIN_DURATION=3.5
const TAIJI_DURATION=6.0


func _ready() -> void:
 world=training.world
 actor=training.actor
 for name in world.spec.texture_paths:textures[name]=load("res://"+world.spec.texture_paths[name])




func add_visual(node: Node2D) -> void:
    world.add_child(node)
    visuals.append(node)




func sprite(name: String, at: Vector2, scale_factor: float=1.0, layer: int=5) -> Sprite2D:
    var node:=Sprite2D.new()
    node.texture=textures[name]
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    node.global_position=at
    node.scale=Vector2.ONE*scale_factor
    node.z_index=layer
    add_visual(node)
    return node




func clear() -> void:
    restore_ink_material()
    for node in visuals:
        if is_instance_valid(node): node.queue_free()
    visuals.clear()
    petals.clear()
    bolts.clear()
    ink_projectiles.clear()
    kind=""
    phase=""
    aura_remaining=0
    taiji_disc=null
    cast_flash=null
    ink_charge=null
    ink_power=0




func restore_ink_material() -> void:
    if ink_material and is_instance_valid(actor) and actor.animated_sprite.material==ink_material:
        actor.animated_sprite.material=actor_original_material
    ink_material=null
    actor_original_material=null




func drop_palm() -> void:
    training.sfx.play("rulai_fall")
    var target:=center+direction*125
    var palm:=sprite("buddha_hand_back_v2",target+Vector2(0,-500),0.7,8)
    palm.rotation=direction.angle()+PI/2.0
    palm.modulate=Color(1,0.9,0.62,0.75)
    var tween:=palm.create_tween().set_parallel(true)
    tween.tween_property(palm,"global_position",target+Vector2(0,-45),0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(palm,"scale",Vector2.ONE*2.3,0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(palm,"modulate:a",1.0,0.62)
    tween.finished.connect(func(): impact_palm(target,palm),CONNECT_ONE_SHOT)




func impact_palm(target: Vector2, palm: Sprite2D) -> void:
    if not is_instance_valid(palm): return
    training.sfx.play("rulai_impact")
    phase="impact"
    var crater:=sprite("buddha_crater",target+Vector2(0,-5),0.5,-1)
    crater.reparent(world.entities)
    crater.z_index=0
    crater.rotation=palm.rotation
    var sideways:=absf(direction.x)>0.5
    var crater_size:=Vector2(0.92,1.65) if sideways else Vector2(1.65,0.92)
    crater.scale=crater_size*0.3
    crater.modulate.a=0.0
    var crater_tween:=crater.create_tween().set_parallel(true)
    crater_tween.tween_property(crater,"scale",crater_size,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    crater_tween.tween_property(crater,"modulate:a",1.0,0.12)
    var fade:=crater.create_tween()
    fade.tween_interval(2.1)
    fade.tween_property(crater,"modulate:a",0.0,0.7)
    var palm_tween:=palm.create_tween().set_parallel(true)
    var pressed_size:=Vector2(0.85,2.4) if sideways else Vector2(2.4,0.85)
    palm_tween.tween_property(palm,"scale",pressed_size,0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    palm_tween.tween_property(palm,"modulate:a",0.0,0.24)
    for i in range(28):
        var angle:=TAU*float(i)/28.0
        var vector:=Vector2.from_angle(angle)
        var rock:=sprite("buddha_rock",target+Vector2(0,-35),0.55+float(i%4)*0.12,9)
        rock.rotation=angle
        var rock_tween:=rock.create_tween().set_parallel(true)
        rock_tween.tween_property(rock,"global_position",target+vector*(110+float(i%5)*25)+Vector2(0,-22),0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        rock_tween.tween_property(rock,"rotation",angle+3.0,0.55)
        rock_tween.tween_property(rock,"modulate:a",0.0,0.55).set_delay(0.18)
    for i in range(20):
        var angle:=TAU*float(i)/20.0
        var vector:=Vector2.from_angle(angle)
        var dust:=sprite("buddha_dust",target+vector*25+Vector2(0,-30),0.75+float(i%3)*0.2,7)
        dust.modulate.a=0.8
        var dust_tween:=dust.create_tween().set_parallel(true)
        dust_tween.tween_property(dust,"global_position",target+vector*(105+float(i%4)*32)+Vector2(0,-30),0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        dust_tween.tween_property(dust,"scale",Vector2.ONE*(1.6+float(i%3)*0.3),0.75)
        dust_tween.tween_property(dust,"modulate:a",0.0,0.75).set_delay(0.15)
    ripple(target+Vector2(0,40),Color(1.0,0.75,0.24,0.95),2.8)
    ripple(target+Vector2(0,40),Color(0.67,0.49,0.31,0.8),2.2)
    for dummy in training.dummies:
        var away: Vector2=dummy.global_position-target
        if away.length()<=210 and not training.blocked(target,dummy):
            training.hit(dummy,120,false)
            if away.length_squared()<1: away=direction
            dummy.create_tween().tween_property(dummy,"position",dummy.position+away.normalized()*70,0.25).set_trans(Tween.TRANS_SINE)
    training.status.text="Palm impact"




func ripple(at: Vector2, tint: Color, size: float=1.0) -> void:
    var ring:=Line2D.new()
    for i in range(49): ring.add_point(Vector2.from_angle(TAU*float(i)/48.0)*70)
    ring.width=7
    ring.default_color=tint
    ring.z_index=7
    ring.global_position=at+Vector2(0,-45)
    add_visual(ring)
    var tween:=ring.create_tween().set_parallel(true)
    tween.tween_property(ring,"scale",Vector2.ONE*size,0.4)
    tween.tween_property(ring,"modulate:a",0.0,0.4)
    tween.finished.connect(func(): if is_instance_valid(ring): ring.queue_free(),CONNECT_ONE_SHOT)




func start(skill: String, facing: Vector2) -> void:
    clear()
    kind=skill
    phase="casting"
    center=actor.global_position
    direction=facing
    clock=0
    phase_clock=0
    reflected_count=0
    training.sfx.play("rulai_flash")
    cast_flash=Sprite2D.new()
    cast_flash.texture=actor.animated_sprite.sprite_frames.get_frame_texture(actor.animated_sprite.animation,0)
    cast_flash.centered=actor.animated_sprite.centered
    cast_flash.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    cast_flash.z_index=6
    var material:=ShaderMaterial.new()
    material.shader=load("res://Shared/GoldenFlash.gdshader")
    cast_flash.material=material
    add_visual(cast_flash)
    cast_flash.global_transform=actor.animated_sprite.global_transform
    cast_flash.modulate.a=0
    var tween:=cast_flash.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    tween.tween_property(cast_flash,"modulate:a",0.95,0.05)
    tween.tween_property(cast_flash,"modulate:a",0.0,0.18)


func cast_finished() -> void:
    phase="strike"
    drop_palm()


func _physics_process(delta:float) -> void:
    if kind=="":return
    clock+=delta
    if clock>4.5:clear()
