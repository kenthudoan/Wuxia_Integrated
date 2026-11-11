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




func update_ink_charge(seconds: float) -> void:
    ink_power=clampf((seconds-1.0)/2.0,0.0,1.0)
    if not is_instance_valid(ink_charge): return
    var progress:=clampf(seconds/3.0,0,1)
    if ink_material: ink_material.set_shader_parameter("charge_progress",progress)
    ink_charge.scale=Vector2.ONE*(0.22+progress*0.4+sin(clock*15.0)*0.015)
    ink_charge.modulate.a=0.35+progress*0.55




func release_ink() -> void:
    if kind!="moying" or not ink_projectiles.is_empty(): return
    training.sfx.play("moying_release",1.1-ink_power*0.25)
    restore_ink_material()
    var ground:=actor.global_position+direction*48
    var slash:=sprite("ink_slash",ground+Vector2(0,-55),0.75+ink_power*0.85,6)
    slash.rotation=direction.angle()
    if is_instance_valid(ink_charge): ink_charge.create_tween().tween_property(ink_charge,"modulate:a",0.0,0.12)
    ink_projectiles.append({"sprite":slash,"ground":ground,"velocity":direction*560,"life":1.2,"trail_clock":0.0})




func ink_impact(at: Vector2, target: Node2D=null) -> void:
    training.sfx.play("moying_impact",1.1-ink_power*0.25)
    var burst:=sprite("ink_impact",at+Vector2(0,-55),0.85,7)
    burst.create_tween().tween_property(burst,"modulate:a",0.0,0.7)
    if target in training.dummies: training.hit(target,70,false)




func update_ink(delta: float) -> void:
    for projectile in ink_projectiles.duplicate():
        var node: Sprite2D=projectile["sprite"]
        var previous: Vector2=projectile["ground"]
        var next: Vector2=previous+projectile["velocity"]*delta
        var ray:=PhysicsRayQueryParameters2D.create(previous+Vector2(0,-5),next+Vector2(0,-5),1)
        ray.exclude=[actor.get_rid()]
        var result:=get_world_2d().direct_space_state.intersect_ray(ray)
        projectile["life"]-=delta
        projectile["trail_clock"]-=delta
        if projectile["trail_clock"]<=0:
            var trace:=sprite("ink_ground_trail",previous+Vector2(0,-3),0.65+ink_power*0.55,0)
            trace.reparent(world.entities)
            trace.rotation=node.rotation
            trace.modulate.a=0.9
            var tween:=trace.create_tween()
            tween.tween_interval(0.45)
            tween.tween_property(trace,"modulate:a",0.0,0.7)
            tween.finished.connect(func(): if is_instance_valid(trace): trace.queue_free(),CONNECT_ONE_SHOT)
            projectile["trail_clock"]=0.04
        if not result.is_empty() or projectile["life"]<=0:
            ink_impact(result["position"] if not result.is_empty() else next,result["collider"] if not result.is_empty() else null)
            node.queue_free()
            ink_projectiles.erase(projectile)
        else:
            projectile["ground"]=next
            node.global_position=(next+Vector2(0,-55)).round()


func start(skill: String, facing: Vector2) -> void:
    clear()
    kind=skill
    phase="casting"
    center=actor.global_position
    direction=facing
    clock=0
    phase_clock=0
    reflected_count=0
    phase="charging"
    actor_original_material=actor.animated_sprite.material
    ink_material=ShaderMaterial.new()
    ink_material.shader=load("res://Shared/InkCharge.gdshader")
    actor.animated_sprite.material=ink_material
    ink_charge=sprite("ink_slash",center+direction*35+Vector2(0,-55),0.22,6)
    ink_charge.rotation=direction.angle()
    ink_charge.modulate.a=0.35


func cast_finished() -> void:
    phase="flight"
    phase_clock=0


func _physics_process(delta:float) -> void:
    training.sfx.set_loop("moying_charge",kind=="moying" and ink_material!=null,0.35+ink_power*0.65,0.75+ink_power*0.5)
    if kind=="":return
    clock+=delta
    phase_clock+=delta
    update_ink(delta)
    if phase=="flight" and ink_projectiles.is_empty() and phase_clock>1.4:clear()
