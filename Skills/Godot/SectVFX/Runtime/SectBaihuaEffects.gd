extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var flowers:Array=[]
var outline:Array=[]
var wisps:Array=[]
var motes:Array=[]
var allies:Array=[]
var heal_rows:Array=[]
var field:AnimatedSprite2D
var decoy_count:=0
var decoy_burst:=false
var dash_blocked:=false
var heal_count:=0
var petals_converged:=0
var fired:=false
var step_finished:=false
var frame_start:=0.0
var pulse_flags=[false,false]
var burst_time:=0.0
var bloom:AnimatedSprite2D
var bloom_born:=0.0
var bloom_scale:=Vector2.ONE
var ghost:AnimatedSprite2D
const PETAL_RADIUS=Vector2(160,92)
const FIELD_RADIUS=Vector2(142,82)
const FLOW_COUNT=27


func clear() -> void:
	super.clear()
	flowers.clear()
	outline.clear()
	wisps.clear()
	motes.clear()
	allies.clear()
	field=null
	bloom=null
	ghost=null
	pass # Targets are private visual markers; never hide game actors.
	if is_instance_valid(world):world.restore_caster_idle()


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var data:Dictionary=skill.phases[phase]
	var factor:float=float(data.logical_canvas[0])/float(data.canvas[0])
	var sprite:=super.spawn(phase,at,size*factor,life,z)
	var halo:ShaderMaterial=pieces[-1].glow.material
	halo.shader=load("res://SectVFX/Runtime/SectBaihuaGlow.gdshader")
	halo.set_shader_parameter("source_texture",textures[data.sheet])
	halo.set_shader_parameter("frame_rect",Vector4(0,0,data.canvas[0],data.canvas[1]))
	var padding:float=4.0/(size*factor)
	pieces[-1].glow.scale=(Vector2(data.canvas[0],data.canvas[1])+Vector2.ONE*padding*2)/2.0
	halo.set_shader_parameter("padding",padding)
	halo.set_shader_parameter("blur_step",1.1/(size*factor))
	halo.set_shader_parameter("tint_low",Vector3(0.76,0.38,0.50))
	halo.set_shader_parameter("tint_high",Vector3(1,0.91,0.81))
	halo.set_shader_parameter("strength",0.35 if mode=="decoy" and phase=="projectile" else 0.48)
	if mode=="heal" and phase=="impact":
		halo.set_shader_parameter("tint_low",Vector3(0.61,0.69,0.37))
		halo.set_shader_parameter("tint_high",Vector3(1,0.99,0.80))
		halo.set_shader_parameter("strength",0.65)
	return sprite


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["petals","decoy","heal"])
	caster=at
	target=dummy
	array_center=dummy.position
	elapsed=0
	hit_count=0
	punishments_fired=0
	decoy_count=0
	decoy_burst=false
	dash_blocked=false
	heal_count=0
	petals_converged=0
	heal_rows.clear()
	pulse_flags=[false,false]
	fired=false
	step_finished=false
	burst_time=0
	active=true
	stage="seed"
	world.sync_caster_action(elapsed)
	match mode:
		"petals":
			for index in range(FLOW_COUNT):
				var lane:int=index/9
				var order:int=index%9
				var flower:Dictionary={"lane":lane,"theta":[-2.65,-0.15,1.65][lane],"spin":[3.8,-3.6,3.5][lane],
					"radius":[1.10,1.02,0.94][lane],"start":0.20+lane*0.13+order*0.075,
					"duration":1.55+lane*0.09,"arrived":false}
				var start:Vector2=flower_position(flower,0)
				if order==0:spawn("cast",start,0.65,0.60)
				var petal:=spawn("projectile",start,0.55+(index*7%5)*0.085,3.4)
				sort_at_ground(petal,start+Vector2(0,42))
				petal.visible=false
				flower.node=petal
				flower.trail=line(1,Color.WHITE,1)
				var gradient:=Gradient.new()
				gradient.colors=PackedColorArray([Color(0.64,0.68,0.40,0),Color(0.78,0.76,0.48,0.70)])
				flower.trail.gradient=gradient
				flowers.append(flower)
		"decoy":
			spawn("cast",caster,1,0.9,-2)
			ghost=spawn("silhouette",caster,1.04,3.5)
			sort_at_ground(ghost,caster)
			var material:=ShaderMaterial.new()
			material.shader=load("res://SectVFX/Runtime/SectBaihuaGhost.gdshader")
			ghost.material=material
			ghost.visible=false
			make_outline()
			dart=line(2,Color(0.86,0.83,0.69),2)
			dart.visible=false
		"heal":
			pass # No hidden training target or spawned NPC required.
			spawn("cast",caster,1,0.7,-2)
			field=spawn("projectile",caster,1.35,4.5,-2)
			var material:=ShaderMaterial.new()
			material.shader=load("res://SectVFX/Runtime/SectBaihuaReveal.gdshader")
			field.material=material
			allies=world.ally_markers.duplicate()
			for index in range(7):
				var petal:=spawn("mote",caster,0.8+index%3*0.12,4.5)
				sort_at_ground(petal,caster)
				petal.visible=false
				motes.append({"node":petal,"phase":index*TAU/7.0})


func make_outline() -> void:
	# The mother is hollow VFX, not an actor frame; sample its actual petal contour for the breakup.
	var data:Dictionary=skill.phases.silhouette
	var image:Image=textures[data.sheet].get_image()
	var factor:float=128.0/image.get_width()
	var anchor:=Vector2(data.anchor[0],data.anchor[1])*factor
	var points:Array[Vector2]=[]
	for y in range(128):
		for x in range(128):
			var point:=Vector2(x,y)
			var source:Vector2i=Vector2i((point+Vector2.ONE*0.5)/factor)
			if image.get_pixelv(source).a>0.55:points.append(point)
	assert(points.size()>40)
	var stride:int=maxi(1,ceili(points.size()/76.0))
	for index in range(0,points.size(),stride):
		var point:Vector2=points[index]
		var at:Vector2=caster+(point-anchor)*1.04
		var petal:=spawn("projectile",at,0.65+index%4*0.10,3.5)
		sort_at_ground(petal,caster)
		petal.visible=false
		outline.append({"node":petal,"home":at,"phase":index*1.87,"scale":petal.scale,
			"velocity":Vector2((-1 if point.x<64 else 1)*(12+index%5*5),-18-index%4*7),"life":0.75+index%5*0.10})
	decoy_count=1


func flower_position(flower:Dictionary,progress:float) -> Vector2:
	var theta:float=flower.theta+progress*flower.spin
	return array_center+Vector2(0,-42)+Vector2(cos(theta),sin(theta))*PETAL_RADIUS*float(flower.radius)*pow(1-progress,0.8)


func update_petals() -> void:
	stage="mark" if elapsed<0.2 else "crossing_spirals" if elapsed<1.95 else "flower_contact"
	for flower in flowers:
		var age:float=elapsed-float(flower.start)
		var progress:float=clampf(age/float(flower.duration),0,1)
		var at:Vector2=flower_position(flower,progress)
		flower.node.visible=age>=0 and progress<1
		flower.node.get_parent().position=at+Vector2(0,42)
		flower.node.global_position=at.round()
		flower.node.rotation=(flower_position(flower,minf(progress+0.005,1))-at).angle()
		flower.node.modulate.a=.84*clampf(age/0.12,0,1)*clampf((1-progress)/0.08,0,1)
		var points:=PackedVector2Array()
		if age>=0:
			# Analytical trailing samples keep the same length when viewport capture slows the frame rate.
			for index in range(10):
				var p:float=clampf(progress-(9-index)*0.028,0,1)
				points.append(flower_position(flower,p).round())
		flower.trail.points=points
		flower.trail.modulate.a=clampf((float(flower.duration)+0.22-age)/0.22,0,1)
		if progress>=1 and not flower.arrived:
			flower.arrived=true
			petals_converged+=1
	if elapsed>=1.95 and not fired:
		fired=true
		if target.position.distance_to(array_center)<36 and not world.training.blocked(caster,target):
			world.training.hit(target,38,false)
			hit_count=1
		bloom=spawn("impact",array_center+Vector2(0,-42),1.55,1.1)
		bloom_born=elapsed
		bloom_scale=bloom.scale
	if is_instance_valid(bloom):
		var age:float=elapsed-bloom_born
		bloom.scale=bloom_scale*(0.72+0.32*sin(clampf(age/0.22,0,1)*PI/2))
		bloom.rotation=0.12*sin(age*4)
		bloom.modulate.a=clampf(age/0.07,0,1)*clampf((1.1-age)/0.4,0,1)
	if elapsed>=3.4:clear()


func burst_decoy() -> void:
	decoy_burst=true
	burst_time=elapsed
	ghost.visible=false
	spawn("impact",caster+Vector2(0,-44),0.55,0.32)


func update_decoy() -> void:
	var progress:float=clampf((elapsed-0.25)/0.60,0,1)
	stage="leave_outline" if elapsed<0.85 else "decoy_wait" if not decoy_burst else "petal_rain"
	ghost.visible=elapsed>=0.30 and not decoy_burst
	ghost.modulate.a=clampf((3.3-elapsed)/0.5,0,1)
	ghost.material.set_shader_parameter("pulse_time",elapsed)
	if elapsed>=0.25 and not step_finished and not dash_blocked:
		var desired:Vector2=curve(caster,caster+ground_offset(Vector2(70,-72)),caster+ground_offset(Vector2(140,-95)),progress)
		if world.player.move_and_collide(desired-world.player.position)!=null:dash_blocked=true
		if progress>=1:step_finished=true
	for petal in outline:
		var node:AnimatedSprite2D=petal.node
		var age:float=elapsed-burst_time
		node.visible=elapsed>=0.30
		if decoy_burst:
			node.global_position=(petal.home+petal.velocity*age+Vector2(sin(age*6+petal.phase)*age*6,48*age*age)).round()
			node.rotation=petal.phase+age*2.5
			node.modulate.a=clampf((float(petal.life)-age)/0.40,0,1)
		else:
			node.global_position=(petal.home+Vector2(sin(elapsed*2+petal.phase)*1.6,cos(elapsed*2.4+petal.phase)*1.1)).round()
			node.rotation=petal.phase+0.25*sin(elapsed*3)
			node.scale=petal.scale*(0.88+0.12*sin(elapsed*3+petal.phase))
			node.modulate.a=(0.65+0.30*sin(elapsed*3+petal.phase))*clampf((3.3-elapsed)/0.5,0,1)
	if send_mock_dart and elapsed>=0.90 and not decoy_burst and not world.training.blocked(caster,target):
		var from:Vector2=target.position+Vector2(0,-44)
		var to:Vector2=caster+Vector2(0,-44)
		var t:float=clampf((elapsed-0.90)/0.65,0,1.2)
		var before:float=clampf((frame_start-0.90)/0.65,0,1.2)
		var at:Vector2=from.lerp(to,t)
		dart.visible=true
		dart.points=PackedVector2Array([at+Vector2(15,-2),at])
		var nearest:Vector2=Geometry2D.get_closest_point_to_segment(to,from.lerp(to,before),at)
		if nearest.distance_to(to)<12 and not world.training.blocked(caster,target):burst_decoy()
	if decoy_burst:dart.modulate.a=0.0
	if elapsed>=3.3:clear()


func update_heal() -> void:
	stage="seed" if elapsed<0.35 else "unfold" if elapsed<1.4 else "support" if elapsed<3.0 else "recede"
	var progress:float=clampf((elapsed-0.35)/1.05,0,1)
	field.material.set_shader_parameter("reveal",progress)
	field.material.set_shader_parameter("dissolve",clampf((elapsed-3.4)/0.8,0,1))
	field.material.set_shader_parameter("pulse_time",elapsed)
	for index in range(2):
		if elapsed>=[0.95,1.4][index] and not pulse_flags[index]:
			pulse_flags[index]=true
			var ally:Node2D=allies[index]
			var inside:bool=((ally.position-caster)/FIELD_RADIUS).length()<=1
			if inside and not world.training.blocked(caster,ally):
				ally.set_meta("test_hp",mini(100,int(ally.get_meta("test_hp"))+12))
				heal_count+=1
				if world.has_method("apply_heal"):world.apply_heal(12)
				for order in range(2):
					var node:=spawn("impact",ally.position,0.95-order*0.12,2.0)
					sort_at_ground(node,ally.position)
					var side:int=1 if order==0 else -1
					node.scale.x*=side
					node.visible=false
					wisps.append({"node":node,"foot":ally.position,"start":elapsed+order*0.42,"side":side,"scale":node.scale})
				heal_rows.append({"index":index,"hp":ally.get_meta("test_hp"),"elapsed":elapsed})
	for wisp in wisps:
		var age:float=elapsed-float(wisp.start)
		if not is_instance_valid(wisp.node):continue
		var node:AnimatedSprite2D=wisp.node
		node.visible=age>=0 and age<1.5
		node.global_position=(wisp.foot+Vector2(wisp.side*7+sin(age*3)*4,-age*16)).round()
		node.scale=wisp.scale*(0.87+0.13*sin(clampf(age/1.5,0,1)*PI))
		node.modulate.a=clampf(age/0.18,0,1)*clampf((1.5-age)/0.45,0,1)
	for mote in motes:
		var theta:float=mote.phase+elapsed*0.75
		var at:Vector2=caster+Vector2(cos(theta),sin(theta))*FIELD_RADIUS+Vector2(0,-5+sin(elapsed*2+mote.phase)*5)
		mote.node.visible=elapsed>=0.75
		mote.node.get_parent().position=at+Vector2(0,5)
		mote.node.global_position=at.round()
		mote.node.rotation=theta+PI/2
		mote.node.modulate.a=0.8*clampf((elapsed-0.75)/0.45,0,1)*clampf((4.0-elapsed)/0.6,0,1)
	if elapsed>=4.5:clear()


func _process(delta:float) -> void:
	if not active:return
	frame_start=elapsed
	elapsed+=delta
	match mode:
		"petals":update_petals()
		"decoy":update_decoy()
		"heal":update_heal()
	if active:world.sync_caster_action(elapsed)
	update_pieces()
	if mode=="heal" and active:
		for piece in pieces:
			if piece.node==field:piece.glow.material.set_shader_parameter("opacity",clampf((elapsed-1.2)/0.3,0,0.30)*clampf((4.2-elapsed)/0.7,0,1))
