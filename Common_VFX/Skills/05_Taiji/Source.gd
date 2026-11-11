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




func spawn_bolt() -> void:
    var source: Node2D=training.dummies[1]
    var node:=Sprite2D.new()
    node.texture=textures["taiji_bolt"]
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    node.modulate=Color(1,1,1,0.9)
    node.z_index=6
    node.global_position=source.global_position+Vector2(0,-55)
    add_visual(node)
    bolts.append({"sprite":node,"source":source,"phase":"incoming","age":0.0,"orbit_angle":0.0})




func finish_bolt(bolt: Dictionary) -> void:
    var node: Sprite2D=bolt["sprite"]
    if is_instance_valid(node): node.queue_free()
    bolts.erase(bolt)




func update_taiji(delta: float) -> void:
    if not is_instance_valid(taiji_disc): return
    taiji_disc.global_position=actor.global_position+Vector2(0,-8)
    taiji_disc.rotation+=delta*(3.0 if reflected_count>0 else 1.2)
    if phase!="aura": return
    aura_remaining-=delta
    bolt_clock-=delta
    if bolt_clock<=0:
        spawn_bolt()
        bolt_clock=1.0
    for bolt in bolts.duplicate():
        var node: Sprite2D=bolt["sprite"]
        var target: Vector2=actor.global_position+Vector2(0,-55)
        bolt["age"]+=delta
        match bolt["phase"]:
            "incoming":
                var step: Vector2=(target-node.global_position).normalized()*280*delta
                node.global_position+=step
                node.rotation=step.angle()
                if node.global_position.distance_to(target)<80:
                    training.sfx.play("taiji_absorb")
                    bolt["phase"]="orbit"
                    bolt["age"]=0.0
                    bolt["orbit_angle"]=(node.global_position-target).angle()
            "orbit":
                var angle: float=bolt["orbit_angle"]+TAU*bolt["age"]/0.6
                node.global_position=target+Vector2.from_angle(angle)*70
                node.rotation=angle+PI/2.0
                if bolt["age"]>=0.6:
                    training.sfx.play("taiji_reflect")
                    bolt["phase"]="reflected"
                    bolt["age"]=0.0
                    reflected_count+=1
                    ripple(actor.global_position,Color(0.85,0.85,0.92,0.9),1.45)
                    ripple(actor.global_position,Color(0.08,0.07,0.12,0.9),1.15)
            "reflected":
                var source: Node2D=bolt["source"]
                var step: Vector2=(source.global_position+Vector2(0,-55)-node.global_position).normalized()*450*delta
                node.global_position+=step
                node.rotation=step.angle()
                if node.global_position.distance_to(source.global_position+Vector2(0,-55))<24:
                    training.sfx.play("sword_hit")
                    training.hit(source,40,false)
                    finish_bolt(bolt)
        if bolt["age"]>3.0: finish_bolt(bolt)
    if aura_remaining<=0: clear()




func start(skill: String, facing: Vector2) -> void:
    clear()
    kind=skill
    phase="casting"
    center=actor.global_position
    direction=facing
    clock=0
    phase_clock=0
    reflected_count=0
    training.sfx.play("taiji_open")
    taiji_disc=sprite("taiji",center+Vector2(0,-8),0.72,-1)
    taiji_disc.modulate.a=0
    taiji_disc.create_tween().tween_property(taiji_disc,"modulate:a",0.85,0.4)


func cast_finished() -> void:
    phase="aura"
    aura_remaining=TAIJI_DURATION
    bolt_clock=0.5


func _physics_process(delta:float) -> void:
    training.sfx.set_loop("taiji_aura",kind=="taiji" and phase=="aura")
    if kind=="":return
    clock+=delta
    update_taiji(delta)
