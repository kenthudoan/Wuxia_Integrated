extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var moons:Array=[]
var ghosts:Array=[]
var frost_front:AnimatedSprite2D
var dash_wind:AnimatedSprite2D
var dash_trail:Dictionary={}
var origin:=Vector2.ZERO
var aim:=Vector2.ZERO
var outbound_hits:=0
var return_hits:=0
var freeze_started:=false
var freeze_finished:=false
var freeze_until:=0.0
var blocked_steps:=0
var dash_blocked:=false
var dash_finished:=false
var ghost_count:=0
var original_color:=Color.WHITE
const MOON_START:=0.42
const MOON_OUT:=0.9
const MOON_TURN:=0.26
const MOON_BACK:=1.05
const DASH_START:=0.32
const DASH_TIME:=0.56


func clear() -> void:
	if is_instance_valid(target):
		if target.has_meta("frost_rooted"):target.remove_meta("frost_rooted")
		target.modulate=original_color
	super.clear()
	moons.clear()
	ghosts.clear()
	frost_front=null
	dash_wind=null
	dash_trail={}
	if is_instance_valid(world):world.restore_caster_idle()


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var node:=super.spawn(phase,at,size,life,z)
	if mode=="moons" and phase=="projectile":pieces[-1].glow.material.set_shader_parameter("strength",.48)
	if mode=="frost" and phase=="impact":
		pieces[-1].glow.material.set_shader_parameter("strength",.28)
		pieces[-1].glow.material.set_shader_parameter("tint_low",Vector3(.42,.62,.80))
		pieces[-1].glow.material.set_shader_parameter("tint_high",Vector3(.78,.90,.98))
	return node


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["moons","frost","dash"])
	caster=at
	target=dummy
	original_color=target.modulate
	array_center=dummy.position
	origin=caster+cast_forward()*25+Vector2(0,-48)
	aim=target.position+Vector2(0,-48)
	elapsed=0
	hit_count=0
	punishments_fired=0
	outbound_hits=0
	return_hits=0
	freeze_started=false
	freeze_finished=false
	blocked_steps=0
	dash_blocked=false
	dash_finished=false
	ghost_count=0
	active=true
	stage="gather"
	spawn("cast",caster+cast_forward()*15 if mode in ["frost","dash"] else origin,1,0.6,-2 if mode!="moons" else 2)
	match mode:
		"moons":
			for side in [-1,1]:
				var blade:=spawn("projectile",origin,2.0,3.2)
				var holder:=sort_at_ground(blade,caster)
				moons.append({"node":blade,"holder":holder,"side":side,"previous":origin,"out":false,"back":false,"stopped":false,"trail":new_trail(2)})
		"frost":prepare_frost()
		"dash":
			dash_wind=spawn("projectile",origin,2.0,1.4)
			dash_wind.visible=false
			dash_wind.rotation=cast_forward().angle()
			dash_trail=new_trail(-1)
			dash_trail.hard.width=1.0
			dash_trail.hard.width_curve=null
			dash_trail.hard.default_color=Color(.60,.78,.90,.40)
			dash_trail.soft.width=6
			dash_trail.soft.default_color=Color(.67,.82,.97,.16)
	world.sync_caster_action(0)


func new_trail(z:int) -> Dictionary:
	var hard:=line(1.5,Color(0.80,0.89,1,0.8),z)
	hard.width_curve=Curve.new()
	hard.width_curve.add_point(Vector2(0,0))
	hard.width_curve.add_point(Vector2(1,1))
	return {"hard":hard,"soft":line(11,Color(0.71,0.83,1,0.4),z),"points":[],"times":[]}


func draw_trail(data:Dictionary,at:Vector2,keep:float) -> void:
	data.points.append(at)
	data.times.append(elapsed)
	while not data.times.is_empty() and elapsed-data.times[0]>keep:
		data.times.pop_front()
		data.points.pop_front()
	data.hard.points=PackedVector2Array(data.points)
	data.soft.points=data.hard.points
	data.soft.visible=glow_enabled


func wall_between(from:Vector2,to:Vector2) -> bool:
	return world.path_blocked(from,to)


func update_moons() -> void:
	var age:float=elapsed-MOON_START
	stage="gather" if age<0 else "outbound" if age<MOON_OUT else "turn" if age<MOON_OUT+MOON_TURN else "return"
	for moon in moons:
		var blade:AnimatedSprite2D=moon.node
		blade.visible=age>=0 and not moon.stopped
		if age<0 or moon.stopped:continue
		var side:float=moon.side
		var end:Vector2=aim+ground_offset(Vector2(0,side*12))
		var far:Vector2=aim+ground_offset(Vector2(56,-side*32))
		var midpoint:Vector2=origin.lerp(aim,0.5)
		var at:Vector2
		if age<MOON_OUT:
			at=curve(origin,midpoint+ground_offset(Vector2(0,side*110)),end,clampf(age/MOON_OUT,0,1))
		elif age<MOON_OUT+MOON_TURN:
			at=curve(end,aim+ground_offset(Vector2(110,side*60)),far,(age-MOON_OUT)/MOON_TURN)
		else:
			var progress:float=clampf((age-MOON_OUT-MOON_TURN)/MOON_BACK,0,1)
			var crossing:Vector2=aim+ground_offset(Vector2(0,-side*12))
			at=curve(far,aim+ground_offset(Vector2(40,-side*48)),crossing,progress/0.27) if progress<0.27 else curve(crossing,midpoint+ground_offset(Vector2(0,-side*110)),origin,(progress-0.27)/0.73)
		if wall_between(moon.previous+Vector2(0,48),at+Vector2(0,48)):
			moon.stopped=true
			blade.visible=false
			moon.trail.hard.visible=false
			moon.trail.soft.visible=false
			continue
		var contact:Vector2=Geometry2D.get_closest_point_to_segment(target.position+Vector2(0,-48),moon.previous,at)
		var returning:bool=age>=MOON_OUT+MOON_TURN
		var key:String="back" if returning else "out"
		if target.visible and not moon[key] and contact.distance_to(target.position+Vector2(0,-48))<30:
			moon[key]=true
			world.training.hit(target,8 if not returning else 12,false)
			hit_count+=1
			if returning:return_hits+=1
			else:outbound_hits+=1
			spawn("impact",target.position+Vector2(0,-48),1.5 if returning else 0.85,0.55)
		blade.rotation=(at-moon.previous).angle()
		moon.holder.position=at+Vector2(0,48)
		blade.global_position=at.round()
		draw_trail(moon.trail,at,0.42)
		moon.previous=at
		blade.modulate.a=clampf((3.05-elapsed)/0.25,0,1)
		moon.trail.hard.modulate.a=blade.modulate.a
		moon.trail.soft.modulate.a=blade.modulate.a
	for piece in pieces:
		if piece.phase=="projectile":piece.clip_time=minf(maxf(0,age),0.34)
	if elapsed>=3.05:clear()


func prepare_frost() -> void:
	var start:Vector2=caster+cast_forward()*22+Vector2(0,-2)
	beam_end=target.position+cast_forward()*44
	var length:float=maxf(0,(wall_endpoint()-start).dot(cast_forward()))
	frost_front=spawn("projectile",start,1,3.7,-2)
	frost_front.rotation=cast_forward().angle()
	var canvas:Array=skill.phases.projectile.canvas
	var anchor:Array=skill.phases.projectile.anchor
	frost_front.scale=Vector2(length/maxf(1,float(canvas[0])-float(anchor[0])),240.0/float(canvas[1]))
	if skill.phases.projectile.get("motion","")=="ground_reveal":
		var material:=ShaderMaterial.new()
		material.shader=load("res://SectVFX/Runtime/SectFrostReveal.gdshader")
		material.set_shader_parameter("origin_x",float(anchor[0])/float(canvas[0]))
		frost_front.material=material
		pieces[-1].glow.material.set_shader_parameter("strength",.55)


func update_frost() -> void:
	var advance:float=clampf((elapsed-0.35)/0.95,0,1)
	stage="gather" if elapsed<0.35 else "spread" if advance<1 else "root" if elapsed<2.85 else "shatter"
	var opacity:float=clampf((3.45-elapsed)/0.6,0,1)
	frost_front.modulate.a=opacity
	if frost_front.material!=null:
		frost_front.material.set_shader_parameter("advance",advance)
		frost_front.material.set_shader_parameter("breakup",clampf((elapsed-2.85)/0.6,0,1))
	if not freeze_started and elapsed>=1.3:
		freeze_started=true
		var offset:Vector2=target.position-caster
		var reach:float=(array_center-caster).dot(cast_forward())+44
		var along:float=offset.dot(cast_forward())
		if along>22 and along<=reach and absf(offset.dot(cast_forward().orthogonal()))<=82*along/maxf(1,reach) and not world.training.blocked(caster,target):
			freeze_until=2.85
			target.set_meta("frost_rooted",true)
			target.modulate=Color(0.83,0.91,1)
			world.training.hit(target,16,false)
			hit_count=1
			spawn("impact",target.position,1.6,1.9,-1)
			pieces[-1].root_hold=true
			spawn("cast",target.position,1,1.9,-2)
	if freeze_started and not freeze_finished and elapsed>=2.85:
		freeze_finished=true
		if target.has_meta("frost_rooted"):
			target.remove_meta("frost_rooted")
			target.modulate=original_color
			# The held native crystal now plays its own breakup, without a second overlapping cluster.
	for piece in pieces:
		if piece.phase=="projectile":piece.clip_time=minf(maxf(0,elapsed-0.35),0.56) if elapsed<2.85 else 0.56+(elapsed-2.85)
		if piece.phase=="impact":
			var age:float=elapsed-piece.born
			piece.clip_time=minf(age,.21) if piece.get("root_hold",false) and elapsed<2.85 else .21+maxf(0,elapsed-2.85)*.70 if piece.get("root_hold",false) else .21+age*.70

	if elapsed>=3.5:clear()


func try_move_target(step:Vector2) -> void:
	if mode=="frost" and is_instance_valid(target) and target.has_meta("frost_rooted"):
		blocked_steps+=1
		return
	if is_instance_valid(target):target.position+=step


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
	ghost.modulate=Color(1,1,1,0.30)
	var material:=ShaderMaterial.new()
	material.shader=load("res://SectVFX/Runtime/SectAfterimage.gdshader")
	ghost.material=material
	holder.add_child(ghost)
	ghosts.append({"node":ghost,"born":elapsed,"life":.38})
	ghost_count+=1


func update_dash() -> void:
	var progress:float=clampf((elapsed-DASH_START)/DASH_TIME,0,1)
	stage="gather" if elapsed<DASH_START else "glide" if progress<1 else "settle"
	if elapsed>=DASH_START and not dash_finished:
		var landing:Vector2=array_center-cast_forward()*55
		var desired:Vector2=curve(caster,caster.lerp(landing,0.5)+ground_offset(Vector2(0,-28)),landing,progress)
		var step:Vector2=desired-world.player.position
		if not dash_blocked:
			var collision=world.player.move_and_collide(step)
			if collision!=null:dash_blocked=true
		dash_wind.visible=not dash_blocked
		dash_wind.position=world.player.position+cast_forward()*22+Vector2(0,-30)
		draw_trail(dash_trail,world.player.position+Vector2(0,-20),0.35)
		var streak:=PackedVector2Array()
		for index in range(17):
			var t:float=clampf(progress-(16-index)*.035,0,1)
			var at:Vector2=curve(caster,caster.lerp(landing,.5)+ground_offset(Vector2(0,-28)),landing,t)
			streak.append((at+Vector2(0,-20)+ground_offset(Vector2(0,sin(t*PI)*6))).round())
		dash_trail.hard.points=streak
		dash_trail.soft.points=streak
		if progress>=0.16 and ghost_count==0:make_ghost(world.player.position)
		if progress>=0.48 and ghost_count==1:make_ghost(world.player.position)
		if progress>=0.78 and ghost_count==2:make_ghost(world.player.position)
		if progress>=1:
			dash_finished=true
			if not dash_blocked and world.player.position.distance_to(target.position)<85 and not world.training.blocked(world.player.position,target):
				world.training.hit(target,24,false)
				hit_count=1
				spawn("impact",target.position+Vector2(0,-48),1.7,0.55)
			spawn("cast",world.player.position,1.2,0.5,-2)
	for ghost in ghosts:
		var age:float=elapsed-ghost.born
		ghost.node.modulate.a=.30*clampf(age/.045,0,1)*clampf((ghost.life-age)/.30,0,1)
	for piece in pieces:
		if piece.phase=="projectile":piece.clip_time=minf(maxf(0,elapsed-DASH_START),0.4) if not dash_finished else 0.4+maxf(0,elapsed-DASH_START-DASH_TIME)
	if not dash_trail.is_empty():
		dash_trail.hard.modulate.a=clampf((1.35-elapsed)/0.5,0,1)
		dash_trail.soft.modulate.a=dash_trail.hard.modulate.a
		dash_trail.soft.visible=glow_enabled
	if elapsed>=1.48:clear()


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	match mode:
		"moons":update_moons()
		"frost":update_frost()
		"dash":update_dash()
	if active:world.sync_caster_action(elapsed)
	update_pieces()
	if mode=="frost" and active and frost_front.material!=null:
		for piece in pieces:
			if piece.node==frost_front:
				piece.glow.material.set_shader_parameter("opacity",frost_front.modulate.a*clampf((elapsed-1.2)/0.15,0,1))
