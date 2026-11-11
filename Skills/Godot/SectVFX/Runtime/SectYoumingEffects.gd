extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var crescent:Node2D
var crescent_glows:Array=[]
var shadow_ribbon:AnimatedSprite2D
var restraint:AnimatedSprite2D
var lunar:AnimatedSprite2D
var strike:AnimatedSprite2D
var ghosts:Array=[]
var flecks:Array=[]
var ink_shards:Array=[]
var chips:Array=[]
var ribbon_scale:=Vector2.ONE
var lunar_scale:=Vector2.ONE
var strike_scale:=Vector2.ONE
var strike_born:=0.0
var original_caster_color:=Color.WHITE
var reach_valid:=false
var bound:=false
var bound_once:=false
var blocked_steps:=0
var dash_finished:=false
var dash_blocked:=false
var ghost_count:=0
var inward_radius:=152.0
const RANGE:=360.0
const FIELD_RADIUS:=Vector2(144,46)
const BIND_ARRIVE:=0.85
const DASH_START:=0.35
const DASH_TIME:=0.42
const ECLIPSE_COLLAPSE:=2.45


func clear() -> void:
	if is_instance_valid(target) and target.has_meta("shadow_rooted"):target.remove_meta("shadow_rooted")
	if world!=null and is_instance_valid(world.caster_preview):world.caster_preview.modulate=original_caster_color
	super.clear()
	crescent=null
	crescent_glows.clear()
	shadow_ribbon=null
	restraint=null
	lunar=null
	strike=null
	ghosts.clear()
	flecks.clear()
	ink_shards.clear()
	chips.clear()
	bound=false
	if is_instance_valid(world):world.restore_caster_idle()


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var data:Dictionary=skill.phases[phase]
	var factor:float=float(data.logical_canvas[0])/data.canvas[0]
	var sprite:=super.spawn(phase,at,size*factor,life,z)
	var core:=ShaderMaterial.new()
	core.shader=load("res://SectVFX/Runtime/SectYoumingSprite.gdshader")
	sprite.material=core
	core.set_shader_parameter("dark_alpha",data.get("dark_alpha",.10 if phase in ["ink","ribbon"] else (.26 if phase=="coil" else .18)))
	var halo:ShaderMaterial=pieces[-1].glow.material
	halo.shader=load("res://SectVFX/Runtime/SectYoumingGlow.gdshader")
	halo.set_shader_parameter("source_texture",textures[data.sheet])
	halo.set_shader_parameter("frame_rect",Vector4(0,0,data.canvas[0],data.canvas[1]))
	var padding:float=5.0/(size*factor)
	pieces[-1].glow.scale=(Vector2(data.canvas[0],data.canvas[1])+Vector2.ONE*padding*2)/2
	halo.set_shader_parameter("padding",padding)
	halo.set_shader_parameter("blur_step",.8/(size*factor))
	halo.set_shader_parameter("strength",.38 if phase in ["moon","ink"] else .48)
	for material in [core,halo]:
		material.set_shader_parameter("canvas_size",Vector2(data.canvas[0],data.canvas[1]))
		material.set_shader_parameter("center_uv",Vector2(data.anchor[0],data.anchor[1])/Vector2(data.canvas[0],data.canvas[1]))
	return sprite


func parameter(node:AnimatedSprite2D,key:String,value:Variant) -> void:
	node.material.set_shader_parameter(key,value)
	for piece in pieces:
		if piece.node==node:piece.glow.material.set_shader_parameter(key,value)


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["bind","shadow_dash","eclipse"])
	caster=at
	target=dummy
	array_center=dummy.position
	original_caster_color=world.caster_preview.modulate
	elapsed=0
	hit_count=0
	punishments_fired=0
	blocked_steps=0
	bound_once=false
	dash_finished=false
	dash_blocked=false
	ghost_count=0
	wall_stopped=false
	released=false
	inward_radius=152
	active=true
	stage="shadow_gather"
	world.sync_caster_action(elapsed)
	beam_end=array_center
	var limit:Vector2=wall_endpoint()
	reach_valid=(array_center-caster).dot(cast_forward())>35 and caster.distance_to(array_center)<=RANGE and limit.distance_to(array_center)<3
	ground_pulse(caster+cast_forward()*8,0.36,0.50)
	if mode in ["bind","shadow_dash"]:
		var start:=caster+cast_forward()*20
		var end:Vector2=limit if mode=="bind" else array_center+ground_offset(Vector2(58,-6))
		if not reach_valid:end=caster+(limit-caster).limit_length(RANGE)
		shadow_ribbon=spawn("ribbon",start,1,2.9 if mode=="bind" else 1.75,-1)
		shadow_ribbon.scale.x*=maxf(1,start.distance_to(end))/float(skill.phases.ribbon.visible_size[0])
		shadow_ribbon.scale.y*=0.82
		shadow_ribbon.rotation=(end-start).angle()
		ribbon_scale=shadow_ribbon.scale
		var box:Array=skill.phases.ribbon.visible_bbox_alpha8
		var canvas:Array=skill.phases.ribbon.canvas
		parameter(shadow_ribbon,"reveal_bounds",Vector2(float(box[0])/canvas[0],float(box[2])/canvas[0]))
		parameter(shadow_ribbon,"advance",0.0)
	else:
		lunar=spawn("moon",array_center,1,3.35,-1)
		lunar_scale=lunar.scale
		parameter(lunar,"ellipse_ratio",0.36)
		for i in range(8):
			var fleck:=line(3 if i%3 else 4,Color(0.60,0.28,0.88,1),-1)
			flecks.append({"node":fleck,"angle":i*TAU/8+0.13,"radius":124.0+i%3*12,"previous_radius":160.0})
		make_crescent()
		for i in range(3):
			var theta:float=-2.65+i*2.05
			var ground:=array_center+Vector2(cos(theta),sin(theta))*FIELD_RADIUS*0.88
			var node:=spawn("ink",ground,0.48+i%3*0.10,3.4)
			sort_at_ground(node,ground)
			ink_shards.append({"node":node,"angle":theta,"scale":node.scale,"delay":0.18+i*0.06})
	if mode=="shadow_dash":make_ghost(caster)


func contact_valid() -> bool:
	return reach_valid and target.position.distance_to(array_center)<30 and open_path(target.position)


func open_path(destination:Vector2) -> bool:
	# Training bodies are targets, not terrain that occludes a ground field.
	beam_end=destination
	return wall_endpoint().distance_to(destination)<3


func impact(at:Vector2,flat:bool=false) -> void:
	strike=spawn("impact",at,0.90 if flat else 1.12,0.62,-1 if flat else 2)
	if not flat:sort_at_ground(strike,array_center+Vector2(0,2))
	if flat:
		strike.scale.y*=0.32
		strike.rotation=-0.12
	strike_scale=strike.scale
	strike_born=elapsed
	shadow_chips(array_center,flat)
	if not flat:ground_pulse(array_center,0.52,0.38)


func ground_pulse(at:Vector2,size:float,life:float) -> void:
	var pulse:=spawn("moon",at,size,life,-1)
	pieces[-1].pulse_scale=pulse.scale
	pieces[-1].pulse_life=life


func shadow_chips(at:Vector2,inward:bool) -> void:
	for i in range(8):
		var theta:float=i*TAU/8+0.21
		var edge:=Vector2(cos(theta)*74,sin(theta)*28)
		var node:=spawn("ink",at,0.14+i%3*0.035,0.66)
		sort_at_ground(node,at)
		chips.append({"node":node,"home":at,"edge":edge,"inward":inward,"born":elapsed,"angle":theta})


func try_move_target(step:Vector2) -> void:
	if bound:
		blocked_steps+=1
		return
	if is_instance_valid(target):target.position+=step


func update_bind() -> void:
	var progress:float=clampf((elapsed-0.28)/(BIND_ARRIVE-0.28),0,1)
	stage="ground_creep" if progress<1 else "ankle_waist_bind" if bound else "shadow_release"
	parameter(shadow_ribbon,"advance",progress)
	shadow_ribbon.modulate.a=clampf(elapsed/0.20,0,1)*clampf((2.75-elapsed)/0.55,0,1)
	if elapsed>=BIND_ARRIVE and not released:
		released=true
		if contact_valid():
			world.training.hit(target,18,false)
			hit_count=1
			bound=true
			bound_once=true
			target.set_meta("shadow_rooted",true)
			ground_pulse(array_center,0.62,0.44)
			shadow_chips(array_center,true)
			restraint=spawn("coil",array_center,1,1.95)
			sort_at_ground(restraint,array_center+Vector2(0,1))
	if is_instance_valid(restraint):
		var growth:float=sin(clampf((elapsed-BIND_ARRIVE)/0.16,0,1)*PI/2)
		var data:Dictionary=skill.phases.coil
		var factor:float=float(data.logical_canvas[0])/data.canvas[0]
		var tension:float=1+0.025*sin((elapsed-BIND_ARRIVE)*12)
		restraint.scale=Vector2(factor*(0.94+0.06*growth)*tension,factor*(0.18+0.82*growth)*.85)
		restraint.modulate.a=clampf((2.65-elapsed)/0.4,0,1)
	if elapsed>=2.55 and bound:
		bound=false
		target.remove_meta("shadow_rooted")
	if elapsed>=2.85:clear()


func make_ghost(at:Vector2) -> void:
	world.sync_caster_action(elapsed)
	var holder:=Node2D.new()
	holder.position=at
	world.entities.add_child(holder)
	extras.append(holder)
	var ghost:=Sprite2D.new()
	ghost.texture=world.caster_preview.texture.duplicate() if world.caster_preview.texture is AtlasTexture else world.caster_preview.texture
	ghost.centered=false
	ghost.position=world.caster_preview.position
	ghost.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate=Color(1,1,1,.34)
	var material:=ShaderMaterial.new()
	material.shader=load("res://SectVFX/Runtime/SectAfterimage.gdshader")
	material.set_shader_parameter("tint_low",Vector3(.42,.31,.56))
	material.set_shader_parameter("tint_high",Vector3(.72,.61,.87))
	ghost.material=material
	holder.add_child(ghost)
	ghosts.append({"node":ghost,"born":elapsed})
	ghost_count+=1


func update_shadow_dash() -> void:
	var progress:float=clampf((elapsed-DASH_START)/DASH_TIME,0,1)
	stage="vanish" if elapsed<DASH_START else "low_shadow_cross" if progress<1 else "back_strike"
	if is_instance_valid(shadow_ribbon):
		parameter(shadow_ribbon,"advance",progress)
		shadow_ribbon.modulate.a=.65*clampf((1.32-elapsed)/0.5,0,1)
	for ghost in ghosts:
		var age:float=elapsed-ghost.born
		ghost.node.modulate.a=.34*clampf((.48-age)/.40,0,1)
	if elapsed>=DASH_START and not dash_finished:
		if progress>=.24 and ghost_count==1:make_ghost(world.player.position)
		if progress>=.62 and ghost_count==2:make_ghost(world.player.position)
		var landing:=array_center+ground_offset(Vector2(58,-6))
		var wanted:Vector2=curve(caster,caster.lerp(landing,0.5)+ground_offset(Vector2(0,-88)),landing,progress)
		if not reach_valid:dash_blocked=true
		if not dash_blocked:
			var collision=world.player.move_and_collide(wanted-world.player.position)
			if collision!=null:dash_blocked=true
		world.caster_preview.modulate.a=0.28 if progress<0.85 and not dash_blocked else 1.0
		if progress>=1:
			dash_finished=true
			world.caster_preview.modulate=original_caster_color
			if not dash_blocked and contact_valid() and world.player.position.distance_to(landing)<4:
				world.training.hit(target,32,false)
				hit_count=1
				impact(array_center+Vector2(0,-44))
	if elapsed>=1.65:clear()


func update_eclipse() -> void:
	stage="broken_lunar_appear" if elapsed<0.5 else "inward_erosion" if elapsed<ECLIPSE_COLLAPSE else "fissure_collapse"
	var collapse:float=clampf((elapsed-ECLIPSE_COLLAPSE)/0.40,0,1)
	var form:float=0.45+0.55*sin(clampf(elapsed/0.24,0,1)*PI/2)
	lunar.scale=lunar_scale*form*(1-collapse*0.85)
	lunar.modulate.a=.20*clampf(elapsed/0.35,0,1)*clampf((3.1-elapsed)/0.35,0,1)
	crescent.scale=Vector2.ONE*form*(1-collapse*.85)
	crescent.modulate.a=.68*clampf(elapsed/.35,0,1)*clampf((3.1-elapsed)/.35,0,1)
	parameter(lunar,"turn",maxf(0,elapsed-0.4)*0.34)
	for row in ink_shards:
		var age:float=elapsed-row.delay
		var theta:float=row.angle+maxf(0,elapsed-0.4)*0.34
		var ground:=array_center+Vector2(cos(theta),sin(theta))*FIELD_RADIUS*0.88*(1-collapse)
		row.node.get_parent().position=ground
		row.node.global_position=ground.round()
		var rise:float=sin(clampf(age/0.16,0,1)*PI/2)
		var recoil:float=1+0.12*sin(maxf(0,age-0.16)*18)*exp(-maxf(0,age-0.16)*6)
		row.node.scale=row.scale*Vector2(1,(0.16+0.84*rise)*recoil)*(1-collapse*0.8)
		row.node.rotation=-cos(theta)*0.16
		row.node.modulate.a=.55*clampf(age/0.18,0,1)*clampf((2.95-elapsed)/0.35,0,1)
	inward_radius=maxf(0,152.0*(1-clampf((elapsed-0.55)/2.25,0,1)))
	for row in flecks:
		var radius:float=row.radius*inward_radius/152.0
		var theta:float=row.angle+elapsed*0.22
		var at:=array_center+Vector2(cos(theta)*radius,sin(theta)*radius*0.32)
		var tail:=Vector2(cos(theta)*7,sin(theta)*2.5)
		row.node.points=PackedVector2Array([at.round(),(at+tail).round()])
		row.node.modulate.a=clampf((elapsed-0.35)/0.3,0,1)*clampf((2.9-elapsed)/0.25,0,1)
		row.previous_radius=radius
	if elapsed>=ECLIPSE_COLLAPSE and not released:
		released=true
		if reach_valid:
			for dummy in world.training.dummies:
				if dummy.visible and ((dummy.position-array_center)/FIELD_RADIUS).length()<=1 and open_path(dummy.position):
					world.training.hit(dummy,30,false)
					hit_count+=1
		impact(array_center,true)
	if elapsed>=3.20:clear()


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	match mode:
		"bind":update_bind()
		"shadow_dash":update_shadow_dash()
		"eclipse":update_eclipse()
	if active:world.sync_caster_action(elapsed)
	if is_instance_valid(strike):
		var age:float=elapsed-strike_born
		strike.scale=strike_scale*(0.75+0.25*sin(clampf(age/0.10,0,1)*PI/2))
		strike.modulate.a=(.78 if mode=="shadow_dash" else 1.0)*clampf(age/0.025,0,1)*clampf((0.56-age)/0.25,0,1)
	for row in chips:
		if not is_instance_valid(row.node):continue
		var age:float=elapsed-row.born
		var t:float=clampf(age/0.6,0,1)
		var ground:Vector2=row.home+row.edge*(1-t if row.inward else sin(t*PI/2))
		row.node.get_parent().position=ground
		row.node.global_position=(ground+Vector2(0,-sin(t*PI)*(18 if row.inward else 38))).round()
		row.node.rotation=row.angle*0.4+t*(0.8 if row.inward else 1.8)
		row.node.modulate.a=clampf(age/0.04,0,1)*clampf((0.6-age)/0.24,0,1)
	for piece in pieces:
		if piece.has("pulse_scale"):
			var age:float=elapsed-piece.born
			piece.node.scale=piece.pulse_scale*(0.70+0.45*sin(clampf(age/0.15,0,1)*PI/2))
			piece.node.modulate.a=clampf(age/0.035,0,1)*clampf((piece.pulse_life-age)/0.22,0,1)
	update_pieces()


func make_crescent() -> void:
	crescent=spawn("crescent_core",array_center,1,3.35,-1)
	pieces[-1].glow.material.set_shader_parameter("strength",.25)
	crescent_glows.append(pieces[-1].glow)


func set_glow_enabled(enabled:bool) -> void:
	super.set_glow_enabled(enabled)
	for glow in crescent_glows:
		if is_instance_valid(glow):glow.visible=enabled
