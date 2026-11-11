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




func update_petals(delta: float) -> void:
    phase_clock+=delta
    if phase=="rain":
        center=actor.global_position
        for petal in petals:
            var node: Sprite2D=petal["sprite"]
            var angle: float=petal["angle"]
            var x: float=cos(angle)*petal["radius"]+sin(clock*2.0+angle)*12
            var y: float=sin(angle)*petal["radius"]*0.25-190+fposmod(petal["fall_offset"]+clock*petal["speed"],210.0)
            node.global_position=(center+Vector2(x,y)).round()
            node.rotation=angle+clock*1.8
        if clock>=PETAL_RAIN_DURATION:
            training.sfx.play("zanghua_scatter")
            phase="blade"
            phase_clock=0
            for petal in petals:
                var node: Sprite2D=petal["sprite"]
                petal["velocity"]=Vector2.from_angle(petal["angle"])*690
                node.scale=Vector2(0.6,0.28)
            for dummy in training.dummies:
                if dummy.global_position.distance_to(center)<=225 and not training.blocked(center,dummy):
                    training.hit(dummy,55,false)
            training.status.text="Petals scatter"
    elif phase=="blade":
        for petal in petals:
            var node: Sprite2D=petal["sprite"]
            node.global_position+=(petal["velocity"]*delta).round()
            node.rotation=petal["velocity"].angle()+PI/2.0
        if phase_clock>=0.48:
            phase="fall"
            phase_clock=0
            for petal in petals:
                var node: Sprite2D=petal["sprite"]
                node.create_tween().tween_property(node,"modulate:a",0.0,0.9)
    elif phase=="fall":
        for petal in petals:
            var node: Sprite2D=petal["sprite"]
            node.global_position+=Vector2(12,55)*delta
            node.rotation+=delta
        if phase_clock>=0.95: clear()
    var visual: AnimatedSprite2D=actor.animated_sprite
    var size:=visual.sprite_frames.get_frame_texture(visual.animation,visual.frame).get_size()
    var corner:=visual.global_position-size*0.5 if visual.centered else visual.global_position
    var body_rect:=Rect2(corner,size).grow(12)
    for petal in petals:
        var node: Sprite2D=petal["sprite"]
        node.visible=not body_rect.has_point(node.global_position)




func start(skill: String, facing: Vector2) -> void:
    clear()
    kind=skill
    phase="casting"
    center=actor.global_position
    direction=facing
    clock=0
    phase_clock=0
    reflected_count=0
    phase="rain"
    for i in range(PETAL_COUNT):
        var petal:=sprite("petal",center+Vector2(0,-55),0.35+float(i%4)*0.06)
        petal.modulate=Color.WHITE if i%3!=0 else Color(0.7,0.12,0.2)
        petals.append({"sprite":petal,"angle":TAU*float(i)/PETAL_COUNT,"radius":35+float(i%8)*15,"fall_offset":fposmod(float(i)*47.0,210.0),"speed":55+float(i%5)*10})
    update_petals(0)


func cast_finished() -> void:
    pass


func _physics_process(delta:float) -> void:
    training.sfx.set_loop("zanghua_rain",kind=="zanghua" and phase=="rain")
    if kind=="":return
    clock+=delta
    update_petals(delta)
