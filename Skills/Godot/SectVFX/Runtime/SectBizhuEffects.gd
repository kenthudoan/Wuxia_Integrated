extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var leaves:Array=[]
var joints:Array=[]
var bits:Array=[]
var bloom:AnimatedSprite2D
var bloom_born:=0.0
var bloom_scale:=Vector2.ONE
var guard:AnimatedSprite2D
var guard_origin:=Vector2.ZERO
var counter:AnimatedSprite2D
var contact_time:=0.0
var bend_pixels:=0.0
var incoming_contact:=false
var incoming_from_front:=true
var counter_count:=0
var converged_count:=0
var joint_count:=0
var dust_count:=0
var stone_count:=0
var shard_count:=0
var break_count:=0
var last_frame:=0.0
const RANGE:=360.0
const ARRIVE:=1.20


func clear() -> void:
	super.clear()
	leaves.clear()
	joints.clear()
	bits.clear()
	bloom=null
	guard=null
	counter=null


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var data:Dictionary=skill.phases[phase]
	var factor:float=float(data.logical_canvas[0])/data.canvas[0]
	var sprite:=super.spawn(phase,at,size*factor,life,z)
	var halo:ShaderMaterial=pieces[-1].glow.material
	halo.shader=load("res://SectVFX/Runtime/SectBizhuGlow.gdshader")
	halo.set_shader_parameter("source_texture",textures[data.sheet])
	halo.set_shader_parameter("frame_rect",Vector4(0,0,data.canvas[0],data.canvas[1]))
	halo.set_shader_parameter("logical_canvas",Vector2(data.logical_canvas[0],data.logical_canvas[1]))
	var padding:float=3.0/(size*factor)
	pieces[-1].glow.scale=(Vector2(data.canvas[0],data.canvas[1])+Vector2.ONE*padding*2)/2
	halo.set_shader_parameter("padding",padding)
	halo.set_shader_parameter("blur_step",0.8/(size*factor))
	if phase in ["dust","debris"]:pieces[-1].glow.visible=false
	return sprite


func set_glow_enabled(enabled:bool) -> void:
	super.set_glow_enabled(enabled)
	for piece in pieces:
		if piece.phase in ["dust","debris"]:piece.glow.visible=false


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["leaves","joints","rebound"])
	caster=at
	target=dummy
	array_center=dummy.position
	elapsed=0
	last_frame=0
	hit_count=0
	punishments_fired=0
	counter_count=0
	converged_count=0
	joint_count=0
	dust_count=0
	stone_count=0
	shard_count=0
	break_count=0
	incoming_contact=false
	bend_pixels=0
	released=false
	deflected=false
	active=true
	stage="gather"
	for i in range(3):
		var seed:=spawn("cast",caster+direction_offset(24+i*6)+Vector2(0,-45-i*5),0.65,0.48)
		sort_at_ground(seed,caster)
		seed.rotation=-0.5+i*0.4
	if mode=="leaves":
		for lane in range(2):
			for order in range(8):
				var node:=spawn("projectile",caster,1.05+order%3*0.14,2.8)
				sort_at_ground(node,caster)
				node.visible=false
				var trail_node:=line(3.2,Color(1,1,1,0.90),1)
				var gradient:=Gradient.new()
				gradient.colors=PackedColorArray([Color(0.42,0.56,0.28,0),Color(0.84,0.94,0.68,0.90)])
				trail_node.gradient=gradient
				leaves.append({"node":node,"lane":lane,"order":order,"start":0.25+lane*0.06+order*0.10,"duration":0.95+order*0.025,"arrived":false,"trail":trail_node})
	elif mode=="rebound":
		guard_origin=caster+direction_offset(40)
		guard=spawn("projectile",guard_origin,1,3.7)
		sort_at_ground(guard,caster)
		var material:=ShaderMaterial.new()
		material.shader=load("res://SectVFX/Runtime/SectBizhuGuard.gdshader")
		material.set_shader_parameter("logical_canvas",Vector2(skill.phases.projectile.logical_canvas[0],skill.phases.projectile.logical_canvas[1]))
		guard.material=material
		dart=line(2,Color(0.83,0.74,0.56),2)
		dart.visible=false


func leaf_position(row:Dictionary,t:float) -> Vector2:
	var start:=caster+direction_offset(26)+Vector2(0,-48)
	var end:=array_center+Vector2(0,-46)
	var control:=start.lerp(end,0.52)+direction_offset(-15,(1 if row.lane else -1)*(190-row.order*3))
	return curve(start,control,end,t)


func impact(at:Vector2) -> void:
	bloom=spawn("impact",at,1.22,0.62)
	sort_at_ground(bloom,at+Vector2(0,46))
	bloom_born=elapsed
	bloom_scale=bloom.scale
	for i in range(6):
		var leaf:=spawn("leaf",at,0.50+i%2*0.12,0.75)
		sort_at_ground(leaf,at+Vector2(0,46))
		bits.append({"node":leaf,"home":at,"born":elapsed,"velocity":Vector2(cos(i*TAU/6),sin(i*TAU/6))*52,"gravity":30,"spin":i-2.5,"life":0.72})


func update_leaves() -> void:
	stage="two_curved_streams" if elapsed<ARRIVE else "leaf_cross_contact"
	for row in leaves:
		var age:float=elapsed-row.start
		var progress:float=clampf(age/row.duration,0,1)
		var at:Vector2=leaf_position(row,progress)
		row.node.visible=age>=0 and progress<1
		row.node.get_parent().position=at+Vector2(0,46)
		row.node.global_position=at.round()
		row.node.rotation=(leaf_position(row,minf(1,progress+0.006))-at).angle()
		row.node.modulate.a=clampf(age/0.08,0,1)*clampf((1-progress)/0.04,0,1)
		var points:=PackedVector2Array()
		if age>=0:
			for i in range(10):points.append(leaf_position(row,clampf(progress-(9-i)*0.018,0,1)).round())
		row.trail.points=points
		row.trail.modulate.a=clampf((row.start+row.duration+0.12-elapsed)/0.12,0,1)
		if progress>=1 and not row.arrived:
			row.arrived=true
			converged_count+=1
	if elapsed>=ARRIVE and not released:
		released=true
		if (array_center-caster).length()<=RANGE and (array_center-caster).dot(facing)>0 and target.position.distance_to(array_center)<32 and not world.training.blocked(caster,target):
			world.training.hit(target,38,false)
			hit_count=1
		impact(array_center+Vector2(0,-46))
	if elapsed>=2.8:clear()


func ground_burst(ground:Vector2,strength:int) -> void:
	for i in range(2+strength):
		var home:=ground+Vector2((i-(1+strength)*0.5)*22,(i%2)*6)
		var dust:=spawn("dust",home,0.58+strength*0.13+i%2*0.10,1.30)
		sort_at_ground(dust,home+Vector2(0,3))
		bits.append({"node":dust,"home":home,"born":elapsed,"velocity":Vector2((i%2*2-1)*(18+strength*6),-12-strength*3),"gravity":0,"spin":0,"life":1.20,"scale":dust.scale})
		dust_count+=1
	for i in range(6+strength*3):
		var stone:=spawn("debris",ground,0.45+strength*0.10+i%3*0.10,1.2)
		sort_at_ground(stone,ground)
		bits.append({"node":stone,"home":ground,"born":elapsed,
			"velocity":Vector2((i%2*2-1)*(45+i*5+strength*12),-130-strength*15-i%3*25),
			"gravity":220,"spin":(i%2*2-1)*(2+i%3),"life":1.15,"land":true})
		stone_count+=1


func break_joint(row:Dictionary) -> void:
	break_count+=1
	var at:Vector2=row.ground+Vector2(14,-64)
	bloom=spawn("impact",at,1.45,0.65)
	sort_at_ground(bloom,row.ground)
	bloom_born=elapsed
	bloom_scale=bloom.scale
	ground_burst(row.ground,2)
	for i in range(12):
		var theta:float=-PI+0.18+i*(PI-0.36)/11.0
		var velocity:=Vector2(cos(theta)*(85+i%3*16),sin(theta)*(115+i%4*14)-18)
		var shard:=spawn("shard",at,0.70+i%4*0.15,0.95)
		sort_at_ground(shard,row.ground)
		bits.append({"node":shard,"home":at,"born":elapsed,"velocity":velocity,"gravity":105,
			"angle":velocity.angle()+PI/3,"spin":(i%2*2-1)*(0.8+i%3*0.6),"life":0.90})
		shard_count+=1


func update_joints() -> void:
	stage="three_joint_sequence"
	while joint_count<3 and elapsed>=0.40+joint_count*0.32:
		var index:=joint_count
		joint_count+=1
		var foot:Vector2=caster+direction_offset(80+index*75,8)
		beam_end=foot
		if wall_endpoint().distance_to(foot)>3:continue
		var node:=spawn("projectile",foot,0.65+index*0.22,1.5)
		sort_at_ground(node,foot)
		joints.append({"node":node,"ground":foot,"born":elapsed,"index":index,"scale":node.scale,"struck":false,"broken":false})
		ground_burst(foot,index)
	for row in joints:
		if not is_instance_valid(row.node):continue
		var age:float=elapsed-row.born
		row.node.scale.y=row.scale.y*(0.2+0.8*sin(clampf(age/0.18,0,1)*PI/2))
		row.node.modulate.a=clampf(age/0.05,0,1)*clampf((1.4-age)/0.50,0,1)
		if row.broken:row.node.modulate.a*=clampf((0.60-age)/0.30,0,1)
		if age>=0.16 and not row.struck:
			row.struck=true
			for dummy in world.training.dummies:
				if dummy.visible and ((dummy.position-row.ground)/Vector2(38,24)).length()<=1 and not world.training.blocked(caster,dummy):
					world.training.hit(dummy,22+row.index*8,false)
					hit_count+=1
		if row.index==2 and age>=0.22 and not row.broken:
			row.broken=true
			break_joint(row)
	if elapsed>=2.7:clear()


func update_rebound() -> void:
	stage="bamboo_guard" if not incoming_contact else "compress" if elapsed<contact_time+0.26 else "elastic_return"
	guard.modulate.a=clampf(elapsed/0.45,0,1)*clampf((3.4-elapsed)/0.45,0,1)
	if send_mock_dart and not incoming_contact and elapsed>=1.0:
		var from:=target.position+Vector2(0,-48)
		var to:=caster+direction_offset(78)+Vector2(0,-50)
		var progress:float=clampf((elapsed-1.0)/0.65,0,1)
		var prior:float=clampf((last_frame-1.0)/0.65,0,1)
		var valid:bool=incoming_from_front and (target.position-caster).dot(facing)>40 and target.position.distance_to(caster)<=RANGE and not world.training.blocked(caster,target)
		dart.visible=valid and progress<1
		var at:Vector2=from.lerp(to,progress)
		dart.points=PackedVector2Array([at+direction_offset(14),at])
		if valid and progress>=1 and prior<1:
			incoming_contact=true
			contact_time=elapsed
	if incoming_contact:
		var age:float=elapsed-contact_time
		bend_pixels=12*sin(clampf(age/0.26,0,1)*PI/2) if age<0.26 else 12*cos(clampf((age-0.26)/0.25,0,1)*PI/2)
		if age>=0.38 and not released:
			released=true
			counter_count=1
			punishments_fired=1
			attack_start=caster+direction_offset(68)+Vector2(0,-52)
			attack_end=array_center+Vector2(0,-46)
			counter=spawn("leaf",attack_start,2.0,0.85)
			sort_at_ground(counter,caster)
		if is_instance_valid(counter):
			var progress:float=clampf((age-0.38)/0.34,0,1)
			counter.global_position=attack_start.lerp(attack_end,progress).round()
			counter.rotation=(attack_end-attack_start).angle()
			counter.modulate.a=clampf((0.95-age)/0.25,0,1)
			if progress>=1 and not deflected:
				deflected=true
				counter.visible=false
				if target.position.distance_to(array_center)<32 and not world.training.blocked(caster,target):
					world.training.hit(target,34,false)
					hit_count=1
				impact(array_center+Vector2(0,-46))
	guard.material.set_shader_parameter("bend_pixels",round(bend_pixels))
	for piece in pieces:
		if piece.node==guard:piece.glow.material.set_shader_parameter("bend_pixels",round(bend_pixels))
	if elapsed>=3.65:clear()


func update_bits() -> void:
	for row in bits:
		if not is_instance_valid(row.node):continue
		var age:float=elapsed-row.born
		var flight:float=minf(age,-row.velocity.y/row.gravity) if row.get("land",false) else age
		row.node.global_position=(row.home+row.velocity*flight+Vector2(0,row.gravity*flight*flight)).round()
		row.node.rotation=row.get("angle",0.0)+age*row.spin
		row.node.modulate.a=clampf(age/0.05,0,1)*clampf((row.life-age)/0.30,0,1)
		if row.has("scale"):
			row.node.scale=row.scale*(0.65+age*0.8)
			row.node.modulate.a*=.48
	if is_instance_valid(bloom):
		var age:float=elapsed-bloom_born
		bloom.scale=bloom_scale*(0.72+0.28*sin(clampf(age/0.10,0,1)*PI/2))
		bloom.modulate.a=clampf(age/0.035,0,1)*clampf((0.58-age)/0.28,0,1)


func _process(delta:float) -> void:
	if not active:return
	last_frame=elapsed
	elapsed+=delta
	match mode:
		"leaves":update_leaves()
		"joints":update_joints()
		"rebound":update_rebound()
	update_bits()
	update_pieces()
