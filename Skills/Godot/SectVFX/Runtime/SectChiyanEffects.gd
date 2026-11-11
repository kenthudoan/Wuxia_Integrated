extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var strikes:Array=[]
var contact_rows:Array=[]
var sweep:AnimatedSprite2D
var sweep_root:Node2D
var sweep_angle:=-PI
var sweep_hit:=false
var attack_direction:=Vector2.RIGHT
var jump_motion:=false
var jump_blocked:=false
var rise_cleave_cut:=false
const JUMP_DISTANCE=160.0
const RING_RADIUS=Vector2(155,55)
const STRIKE_TIMES=[0.42,0.84,1.42]


func clear() -> void:
	super.clear()
	strikes.clear()
	sweep=null
	sweep_root=null
	jump_motion=false
	if is_instance_valid(world):world.restore_caster_idle()


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var sprite:=super.spawn(phase,at,size,life,z)
	var glow:ShaderMaterial=pieces[-1].glow.material
	glow.set_shader_parameter("tint_low",Vector3(0.64,0.12,0.025))
	glow.set_shader_parameter("tint_high",Vector3(1,0.79,0.38))
	glow.set_shader_parameter("strength",0.85)
	if phase in ["projectile","finish_saber"]:
		var reveal:=ShaderMaterial.new()
		reveal.shader=load("res://SectVFX/Runtime/SectChiyanCoreR3.gdshader")
		reveal.set_shader_parameter("reveal_enabled",skill.phases[phase].get("motion","")=="chiyan_reveal")
		reveal.set_shader_parameter("advance",1.0)
		sprite.material=reveal
	return sprite


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["cleave","triple","ring"])
	caster=at
	target=dummy
	attack_direction=(target.position-caster).normalized()
	array_center=target.position
	elapsed=0
	hit_count=0
	punishments_fired=0
	contact_rows.clear()
	sweep_hit=false
	sweep_angle=0.0 if world.caster_actions.has("ring") else -PI
	active=true
	jump_motion=mode=="cleave" and world.current_caster_action().has("airborne_heights")
	rise_cleave_cut=mode=="triple" and world.current_caster_action().has("sequence")
	jump_blocked=false
	stage="gather"
	world.sync_caster_action(elapsed)
	face_vfx(spawn("cast",caster+attack_direction*26+Vector2(0,-48),1.3,0.7))
	if mode=="ring":
		var mother:bool=skill.phases.projectile.get("motion","")=="chiyan_reveal"
		sweep=spawn("projectile",caster+Vector2(0,-25),1.25 if mother else 3.0,1.8)
		sweep_root=sort_at_ground(sweep,caster)
		sweep_root.position=caster+Vector2(0,-25)
		sweep_root.z_index=-1
		sweep.position=Vector2.ZERO
		if mother:
			sweep_root.scale.y=0.5
			sweep.scale.y/=0.5
		sweep.visible=false


func contact(at:Vector2,radius:float,damage:int,phase:int) -> void:
	var origin:Vector2=world.player.position if jump_motion else caster
	var touched:bool=target.position.distance_to(at)<radius and not world.training.blocked(origin,target)
	contact_rows.append({"phase":phase,"elapsed":elapsed,"hit":touched,"at":[at.x,at.y]})
	if touched:
		world.training.hit(target,damage,false)
		hit_count+=1
		spawn("impact",target.position+Vector2(0,-14),1.7 if damage>=35 else 1.1,0.65)


func face_vfx(sprite:AnimatedSprite2D) -> void:
	if attack_direction.is_equal_approx(Vector2.LEFT):
		sprite.rotation=-sprite.rotation
		sprite.scale.x=-sprite.scale.x
	else:sprite.rotation+=attack_direction.angle()


func jump_strike_ground() -> Vector2:
	var start:Vector2=world.player.position
	return world.trace_endpoint(start,start+attack_direction*70.0)


func begin_strike(index:int,starts_at:float) -> void:
	var heavy:bool=mode=="cleave" or index==(1 if rise_cleave_cut else 2)
	var position_ground:Vector2=caster+attack_direction*(230 if mode=="cleave" else 185+index*23)
	if jump_motion or rise_cleave_cut:position_ground=jump_strike_ground()
	var phase:String="finish_saber" if mode=="triple" and heavy else "projectile"
	var mother:bool=skill.phases[phase].get("motion","")=="chiyan_reveal"
	var size:float=1.2 if heavy else 1.25+index*0.2
	if not mother:size=2.6 if heavy else 1.8+index*0.25
	var blade:=spawn(phase,position_ground+Vector2(0,-6 if heavy else -46),size,0.65)
	var ground_root:Node2D=sort_at_ground(blade,position_ground)
	if jump_motion or rise_cleave_cut:ground_root.z_index=-1 # Keep the actor readable through its own flame arc.
	# Late frames catch up to the scheduled phase instead of adding another wind-up delay.
	pieces[-1].born=starts_at
	pieces[-1].expires=starts_at+0.65
	# The heavy atlas' hot contact tip is at [100,100], not its default center anchor.
	if heavy and not mother:
		assert(skill.phases[phase].canvas==[128,128])
		blade.offset=Vector2(-36,-36)
		pieces[-1].glow.position=blade.offset
	if not heavy:
		blade.rotation=deg_to_rad((-35 if index==0 else 12) if rise_cleave_cut else (12 if index==0 else -35))
		if index==(2 if rise_cleave_cut else 0):blade.scale.y*=0.55
	face_vfx(blade)
	strikes.append({"node":blade,"born":starts_at,"index":index,"hit":false,"at":position_ground,"heavy":heavy})


func update_strikes() -> void:
	var times:Array=[0.62] if mode=="cleave" else STRIKE_TIMES
	for index in range(times.size()):
		if elapsed>=times[index] and strikes.size()<=index:begin_strike(index,times[index])
	for strike in strikes:
		if jump_motion or rise_cleave_cut:strike.at=jump_strike_ground()
		var age:float=elapsed-strike.born
		if not strike.hit and age>=0.16:
			strike.hit=true
			contact(strike.at,100 if strike.heavy else 65+strike.index*15,48 if mode=="cleave" else [12,18,36][strike.index],strike.index)
		if is_instance_valid(strike.node) and age<0.65:
			var at:Vector2=strike.at+Vector2(0,-6 if strike.heavy else -46)
			var movement:Vector2=Vector2(0,6) if strike.heavy else Vector2(20,-12 if strike.index==1 else 16).rotated(attack_direction.angle())
			var drop:Vector2=Vector2(0,-55*(1.0-clampf(age/0.16,0,1))) if strike.heavy else Vector2.ZERO
			strike.node.global_position=(at+movement*clampf(age/0.25,0,1)+drop).round()
			if strike.node.material!=null:
				strike.node.modulate.a=minf(clampf(age/0.07,0,1),clampf((0.65-age)/0.22,0,1))
				strike.node.material.set_shader_parameter("breakup",clampf((age-0.34)/0.31,0,1))
	for piece in pieces:
		if piece.phase in ["projectile","finish_saber"]:piece.clip_time=(elapsed-piece.born)*1.55
	stage="gather" if strikes.is_empty() else "heavy_cut" if mode=="cleave" or strikes.size()==3 else "cut_%d"%strikes.size()
	if rise_cleave_cut and not strikes.is_empty():stage=["rise","cleave","horizontal"][strikes.size()-1]
	if elapsed>times[-1]+0.95:clear()


func update_jump_motion() -> void:
	if not jump_motion or jump_blocked:return
	var progress:float=smoothstep(0.24,0.76,elapsed)
	var destination:Vector2=(caster+attack_direction*JUMP_DISTANCE*progress).round()
	# Move the real body and its ground shadow; never teleport the sprite through town geometry.
	var collision=world.player.move_and_collide(destination-world.player.position)
	if collision!=null:jump_blocked=true


func update_sweep() -> void:
	var age:float=elapsed-0.40
	var progress:float=clampf(age/0.8,0,1)
	stage="gather" if age<0 else "sweep" if progress<1 else "embers"
	sweep.visible=age>=0
	var previous_angle:float=sweep_angle
	var actor_spin:bool=world.caster_actions.has("ring")
	# Follow the new actor's right → rear → left turn; the VFX-only baseline keeps its old phase.
	sweep_angle=lerpf(0,-TAU,progress) if actor_spin else lerpf(-PI,PI,progress)
	if skill.phases.projectile.get("motion","")=="chiyan_reveal":
		sweep.rotation=sweep_angle
		sweep.material.set_shader_parameter("breakup",clampf((elapsed-1.2)/0.45,0,1))
		sweep.modulate.a=minf(clampf(age/0.12,0,1),clampf((1.65-elapsed)/0.40,0,1))
	# The flat ring stays projected onto the paving; only its texture phase turns.
	for piece in pieces:
		if piece.node==sweep:piece.clip_time=maxf(0,age)
	if not sweep_hit and age>=0:
		var local:Vector2=(target.position-caster)/RING_RADIUS
		var angle:float=local.angle()
		var crossed:bool=angle>=previous_angle and angle<=sweep_angle
		if actor_spin:crossed=posmod(-angle,TAU)>=-previous_angle and posmod(-angle,TAU)<=-sweep_angle
		if crossed:
			sweep_hit=true
			if local.length()>=0.55 and local.length()<=1.30 and not world.training.blocked(caster,target):
				contact(target.position,1,32,0)
	if elapsed>=1.65:clear()


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	update_jump_motion()
	if mode=="ring":update_sweep()
	else:update_strikes()
	update_pieces()
	for piece in pieces:
		if piece.node.material!=null:
			var age:float=elapsed-piece.born
			var breakup:float=piece.node.material.get_shader_parameter("breakup")
			piece.glow.material.set_shader_parameter("opacity",piece.node.modulate.a*clampf((age-0.12)/0.08,0,1)*(1.0-breakup))
	if active:world.sync_caster_action(elapsed)
