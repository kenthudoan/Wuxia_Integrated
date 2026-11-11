extends "res://SectVFX/Runtime/SectSwordVariants.gd"

var defence:AnimatedSprite2D
var pressure:AnimatedSprite2D
var palm_core:AnimatedSprite2D
var palm_core_scale:=Vector2.ONE
var wave:AnimatedSprite2D
var contact:AnimatedSprite2D
var defence_scale:=Vector2.ONE
var pressure_scale:=Vector2.ONE
var wave_scale:=Vector2.ONE
var wave_base_radius:=Vector2.ONE
var contact_scale:=Vector2.ONE
var contact_born:=0.0
var shock_count:=0
var counter_count:=0
var incoming_contact:=false
var incoming_from_front:=true
var wave_radius:=Vector2.ZERO
var previous_wave_radius:=Vector2.ZERO
var defence_origin:=Vector2.ZERO
var chips:Array=[]
var chip_count:=0
var guardian_motion:=0.0
var dusts:Array=[]
var dust_count:=0
var formation_dust:=false
var palm_victims:Array[int]=[]
const RANGE:=210.0
const PALM_RANGE:=240.0
const PALM_HALF_ANGLE:=0.62


func clear() -> void:
	super.clear()
	defence=null
	pressure=null
	palm_core=null
	wave=null
	contact=null
	chips.clear()
	dusts.clear()


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var data:Dictionary=skill.phases[phase]
	var factor:float=float(data.logical_canvas[0])/float(data.canvas[0])
	var sprite:=super.spawn(phase,at,size*factor,life,z)
	if facing==Vector2.LEFT and phase in ["projectile","counter"] and mode!="bell":sprite.scale.x=-sprite.scale.x
	var halo:ShaderMaterial=pieces[-1].glow.material
	halo.shader=load("res://SectVFX/Runtime/SectJingangGlow.gdshader")
	halo.set_shader_parameter("source_texture",textures[data.sheet])
	halo.set_shader_parameter("frame_rect",Vector4(0,0,data.canvas[0],data.canvas[1]))
	var padding:float=4.0/(size*factor)
	pieces[-1].glow.scale=(Vector2(data.canvas[0],data.canvas[1])+Vector2.ONE*padding*2)/2.0
	halo.set_shader_parameter("padding",padding)
	halo.set_shader_parameter("blur_step",0.9/(size*factor))
	halo.set_shader_parameter("tint_low",Vector3(0.95,0.55,0.04))
	halo.set_shader_parameter("tint_high",Vector3(1.0,0.85,0.18))
	halo.set_shader_parameter("strength",0.32 if phase=="palm_core" or (phase=="projectile" and mode in ["bell","guardian"]) else 0.55)
	if phase in ["debris","dust"]:pieces[-1].glow.visible=false
	return sprite


func set_glow_enabled(enabled:bool) -> void:
	super.set_glow_enabled(enabled)
	for piece in pieces:
		if piece.phase in ["debris","dust"]:piece.glow.visible=false


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["bell","palm","guardian"])
	caster=at
	target=dummy
	array_center=caster
	elapsed=0
	hit_count=0
	punishments_fired=0
	shock_count=0
	counter_count=0
	chip_count=0
	guardian_motion=0
	dust_count=0
	formation_dust=false
	palm_victims.clear()
	incoming_contact=false
	released=false
	deflected=false
	wall_stopped=false
	wave_radius=Vector2.ZERO
	previous_wave_radius=Vector2.ZERO
	active=true
	stage="seed"
	spawn("cast",caster+direction_offset(25)+Vector2(0,-46) if mode=="palm" else caster+Vector2(0,-25),0.80,0.65)
	if mode=="palm":return
	defence_origin=caster+direction_offset(-24)+Vector2(0,-4) if mode=="guardian" else caster
	defence=spawn("projectile",defence_origin,1,3.8)
	sort_at_ground(defence,caster+Vector2(0,-8) if mode=="guardian" else caster)
	defence_scale=defence.scale
	var material:=ShaderMaterial.new()
	material.shader=load("res://SectVFX/Runtime/SectJingangReveal.gdshader")
	defence.material=material
	if mode=="guardian":
		material.set_shader_parameter("guardian_warp",absf(facing.x)>0)
		material.set_shader_parameter("logical_canvas",skill.phases.projectile.logical_canvas[0])
		pieces[-1].glow.material.set_shader_parameter("guardian_warp",absf(facing.x)>0)
		pieces[-1].glow.material.set_shader_parameter("logical_canvas",skill.phases.projectile.logical_canvas[0])
	dart=line(2,Color(0.84,0.72,0.50),2)
	dart.visible=false
	# shortcut: one visible wood-dart fixture, not NPC combat or AI.


func reveal_defence() -> void:
	if not is_instance_valid(defence):return
	var formation:float=clampf((elapsed-0.12)/0.65,0,1)
	defence.material.set_shader_parameter("reveal",formation)
	defence.modulate.a=0.96*clampf((3.5-elapsed)/0.65,0,1)
	for piece in pieces:
		if piece.node==defence:piece.glow.visible=glow_enabled and formation>=1.0
	defence.global_position=defence_origin.round()
	guardian_motion=0
	if incoming_contact:
		var age:float=elapsed-deflect_time
		if mode=="bell":
			defence.global_position.x+=round(sin(age*70)*2*clampf(1-age/0.22,0,1))
		else:
			defence.global_position+=direction_offset(round(5*sin(clampf(age/0.40,0,1)*PI)))
			guardian_motion=sin(clampf(age/0.44,0,1)*PI)
	if mode=="guardian":
		defence.material.set_shader_parameter("counter_motion",guardian_motion)
		for piece in pieces:
			if piece.node==defence:piece.glow.material.set_shader_parameter("counter_motion",guardian_motion)


func incoming(delta:float) -> bool:
	if not send_mock_dart or incoming_contact or elapsed<0.9:return false
	var finish:Vector2=caster+direction_offset(57)+Vector2(0,-48)
	var start:Vector2=target.position+Vector2(0,-48)
	var progress:float=clampf((elapsed-0.9)/0.50,0,1)
	var prior:float=clampf((elapsed-delta-0.9)/0.50,0,1)
	var now:Vector2=start.lerp(finish,progress)
	dart.visible=progress<1
	dart.points=PackedVector2Array([now-(finish-start).normalized()*12,now])
	if progress>=1 and prior<1:
		dart.visible=false
		var offset:Vector2=in_facing(target.position-caster)
		if not incoming_from_front or offset.x<40 or offset.length()>RANGE or world.training.blocked(caster,target):return false
		incoming_contact=true
		deflect_time=elapsed
		return true
	return false


func emit_wave() -> void:
	shock_count=1
	wave=spawn("impact",caster,1,1.0,-1)
	wave_scale=wave.scale
	var data:Dictionary=skill.phases.impact
	wave_base_radius=Vector2(data.visible_radius[0],data.visible_radius[1])
	assert(wave_base_radius.x>1 and wave_base_radius.y>1)


func update_bell(delta:float) -> void:
	stage="forming" if elapsed<0.78 else "guard" if not incoming_contact else "single_ground_wave"
	if incoming(delta):emit_wave()
	if is_instance_valid(wave):
		var age:float=elapsed-deflect_time
		previous_wave_radius=wave_radius
		wave_radius=Vector2(62,24).lerp(Vector2(RANGE,RANGE*0.38),clampf(age/0.72,0,1))
		wave.scale=wave_scale*wave_radius/wave_base_radius
		wave.modulate.a=0.96*clampf(age/0.06,0,1)*clampf((1-age)/0.40,0,1)
		var offset:Vector2=target.position-caster
		if hit_count==0 and previous_wave_radius.x>1:
			var current:float=(offset/wave_radius).length()
			var previous:float=(offset/previous_wave_radius).length()
			if current<=1.03 and previous>1 and not world.training.blocked(caster,target):
				world.training.hit(target,30,false)
				hit_count=1
	if elapsed>=3.7:clear()


func begin_pressure(phase:String) -> void:
	released=true
	attack_start=caster+direction_offset(100)+Vector2(0,-115)
	beam_end=caster+direction_offset(RANGE)
	beam_end=wall_endpoint()
	attack_end=beam_end+Vector2(0,-115)
	pressure=spawn(phase,attack_start,1.0,1.0)
	sort_at_ground(pressure,caster)
	pressure_scale=pressure.scale
	emit_dust(caster+direction_offset(90))


func begin_frontal_palm() -> void:
	released=true
	attack_start=caster+direction_offset(15)+Vector2(0,-38)
	if skill.phases.projectile.get("directional_native",false):attack_start=caster+direction_offset(15)
	pressure=spawn("projectile",attack_start,1.0,0.9)
	if facing not in [Vector2.RIGHT,Vector2.LEFT] and not skill.phases.projectile.get("directional_native",false):pressure.rotation=facing.angle()
	sort_at_ground(pressure,caster)
	pressure_scale=pressure.scale
	palm_core=spawn("palm_core",caster+direction_offset(45)+Vector2(0,-26),1.0,.9)
	palm_core.rotation=facing.angle()+PI/2
	sort_at_ground(palm_core,caster)
	palm_core_scale=palm_core.scale
	emit_chips(caster+direction_offset(115,8))
	emit_dust(caster,true)


func update_frontal_palm(age:float,delta:float) -> void:
	if not is_instance_valid(pressure):return
	# The origin stays on the caster: this is an area strike, never a travelling projectile.
	pressure.global_position=attack_start
	pressure.scale=pressure_scale*(0.88+0.12*sin(clampf(age/0.14,0,1)*PI/2))
	pressure.modulate.a=.28*clampf(age/0.045,0,1)*clampf((0.76-age)/0.40,0,1)
	if is_instance_valid(palm_core):
		palm_core.scale=palm_core_scale*(.88+.12*sin(clampf(age/.16,0,1)*PI/2))
		palm_core.modulate.a=.88*clampf(age/.055,0,1)*clampf((.79-age)/.32,0,1)
	if age>=0.10 and age-delta<=0.32:
		for dummy in world.training.dummies:
			var offset:Vector2=in_facing(dummy.position-caster)
			if not dummy.visible or dummy.get_instance_id() in palm_victims:continue
			if offset.x<=24 or offset.length()>PALM_RANGE or absf(offset.y)>offset.x*PALM_HALF_ANGLE:continue
			if world.training.blocked(caster,dummy):continue
			world.training.hit(dummy,42,false)
			palm_victims.append(dummy.get_instance_id())
			hit_count+=1
	if age>0.32:deflected=true


func update_pressure(age:float) -> void:
	if not is_instance_valid(pressure):return
	var progress:float=clampf(age/0.72,0,1)
	pressure.get_parent().position=(attack_start-Vector2(0,-115)).lerp(beam_end,progress)
	pressure.global_position=attack_start.lerp(attack_end,progress).round()
	pressure.scale=pressure_scale
	pressure.modulate.a=clampf(age/0.045,0,1)*clampf((0.94-age)/0.22,0,1)
	if not deflected:
		var offset:Vector2=in_facing(target.position-caster)
		var front:float=(pressure.global_position-Vector2(0,-115)-caster).dot(facing)
		if not wall_stopped and front>=offset.x and absf(offset.y)<28 and offset.length()<=RANGE and offset.x>0 and not world.training.blocked(caster,target):
			deflected=true
			world.training.hit(target,42 if mode=="palm" else 36,false)
			hit_count=1
			contact=spawn("impact",target.position+Vector2(0,-48),1.0,0.7)
			sort_at_ground(contact,target.position)
			contact_scale=contact.scale
			contact_born=elapsed
			emit_chips(target.position)
			emit_dust(target.position)
		elif progress>=1:deflected=true


func emit_chips(ground:Vector2) -> void:
	var heavy_counter:bool=mode=="guardian" and released
	for index in range(12 if heavy_counter else 8 if mode=="palm" else 10):
		var chip:=spawn("debris",ground,0.65+index%3*0.16,0.95)
		sort_at_ground(chip,ground+Vector2(0,2))
		if mode=="palm":chip.get_parent().z_index=-1
		chips.append({"node":chip,"ground":ground,"born":elapsed,"velocity":Vector2(-110+index*20,-110-index%3*18)*(1.25 if heavy_counter else 1.0),"spin":(-1 if index%2 else 1)*(2+index%3)})
	chip_count=chips.size()


func emit_dust(ground:Vector2,forward:bool=false) -> void:
	for index in range(5):
		var offset:=direction_offset(35+index*43,(-1 if index%2 else 1)*(12+index*5)) if forward else Vector2((index-2)*34,abs(index-2)*7)
		var puff:=spawn("dust",ground+offset,0.85+index%3*0.13,1.35)
		sort_at_ground(puff,ground+offset+Vector2(0,3))
		if mode=="palm":puff.get_parent().z_index=-1
		puff.modulate.a=0
		dusts.append({"node":puff,"ground":ground+offset,"born":elapsed+index*0.035,"scale":puff.scale,
			"velocity":Vector2(14 if forward else (index-2)*12,-10-index%2*5)})
		dust_count+=1


func update_contact() -> void:
	for chip in chips:
		if not is_instance_valid(chip.node):continue
		var age:float=elapsed-chip.born
		var flight:float=minf(age,-chip.velocity.y/190.0)
		chip.node.global_position=(chip.ground+chip.velocity*flight+Vector2(0,190*flight*flight)).round()
		chip.node.rotation=flight*chip.spin
		chip.node.modulate.a=clampf((0.9-age)/0.22,0,1)
	for puff in dusts:
		if not is_instance_valid(puff.node):continue
		var age:float=maxf(0,elapsed-puff.born)
		puff.node.global_position=(puff.ground+puff.velocity*age).round()
		puff.node.scale=puff.scale*(0.70+0.55*clampf(age/0.7,0,1))
		puff.node.modulate.a=(.46 if mode=="palm" else .60)*clampf(age/0.07,0,1)*clampf((1.10-age)/0.45,0,1)
	if not is_instance_valid(contact):return
	var age:float=elapsed-contact_born
	contact.scale=contact_scale*(0.72+0.32*sin(clampf(age/0.12,0,1)*PI/2))
	contact.modulate.a=clampf(age/0.04,0,1)*clampf((0.65-age)/0.3,0,1)


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	match mode:
		"bell":update_bell(delta)
		"palm":
			stage="gather" if elapsed<0.48 else "frontal_area_pressure" if not deflected else "earth_settle"
			if elapsed>=0.48 and not released:begin_frontal_palm()
			if released:update_frontal_palm(elapsed-0.48,delta)
			if elapsed>=2.1:clear()
		"guardian":
			if elapsed>=0.58 and not formation_dust:
				formation_dust=true
				emit_chips(caster)
				emit_dust(caster)
			stage="forming" if elapsed<0.78 else "hold" if not incoming_contact else "short_counter"
			if incoming(delta):
				counter_count=1
				punishments_fired=1
				begin_pressure("counter")
			if released:update_pressure(elapsed-deflect_time)
			if elapsed>=3.7:clear()
	reveal_defence()
	update_contact()
	update_pieces()
