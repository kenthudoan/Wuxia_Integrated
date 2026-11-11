extends "res://SectVFX/Runtime/SectArrayTrap.gd"

var mode:=""
var stage:=""
var released:=false
var deflected:=false
var send_mock_dart:=true
var deflect_time:=0.0
var attack_start:=Vector2.ZERO
var attack_end:=Vector2.ZERO
var beam_end:=Vector2.ZERO
var sword:AnimatedSprite2D
var dart:Line2D
var beam:Line2D
var beam_glow:Line2D
var trail:Line2D
var trail_glow:Line2D
var extras:Array[Node]=[]
var trail_points:Array[Vector2]=[]
var trail_times:Array[float]=[]
var pierced:Array[int]=[]
var wall_stopped:=false
const BEAM_RANGE:=610.0
const RELEASE:=0.58
const ORBIT_RADIUS:=Vector2(104,62)
const ORBIT_CENTER:=Vector2(0,-55)
const GUARD_PERIOD:=3.2


func clear() -> void:
	super.clear()
	for node in extras:
		if is_instance_valid(node):node.queue_free()
	extras.clear()
	trail_points.clear()
	trail_times.clear()
	sword=null
	dart=null
	beam=null
	beam_glow=null
	trail=null
	trail_glow=null
	stage="idle"


func line(width:float,color:Color,z:int=3) -> Line2D:
	var node:=Line2D.new()
	node.width=width
	node.default_color=color
	node.z_index=z
	node.antialiased=false
	if width>6:
		var texture:=GradientTexture2D.new()
		texture.width=2
		texture.height=32
		texture.fill_from=Vector2.ZERO
		texture.fill_to=Vector2(0,1)
		texture.gradient=Gradient.new()
		texture.gradient.offsets=PackedFloat32Array([0,0.3,0.5,0.7,1])
		texture.gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.2),Color.WHITE,Color(1,1,1,0.2),Color(1,1,1,0)])
		node.texture=texture
		node.texture_mode=Line2D.LINE_TEXTURE_STRETCH
		node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		var blend:=CanvasItemMaterial.new()
		blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
		node.material=blend
	world.add_child(node)
	extras.append(node)
	return node


func spawn(phase:String,at:Vector2,size:float,life:float,z:int=2) -> AnimatedSprite2D:
	var sprite:=super.spawn(phase,at,size,life,z)
	# Motion and atlas frames share one clock, including paused viewport evidence capture.
	sprite.pause()
	return sprite


func play(spec:Dictionary,at:Vector2,dummy:Node2D) -> void:
	clear()
	skill=spec
	mode=spec.mode
	assert(mode in ["beam","orbit"])
	caster=at
	target=dummy
	array_center=dummy.position
	elapsed=0
	hit_count=0
	punishments_fired=0
	released=false
	deflected=false
	pierced.clear()
	wall_stopped=false
	active=true
	stage="gather"
	spawn("cast",caster+cast_forward()*26+Vector2(0,-55),1,0.58)
	if mode=="beam":
		beam_glow=line(16,Color(0.8,0.88,1,0.35))
		beam=line(3,Color(1,0.96,0.79))
		beam.width_curve=Curve.new()
		for point in [Vector2(0,0.4),Vector2(0.06,1),Vector2(0.85,0.7),Vector2(1,0)]:beam.width_curve.add_point(point)
		beam_end=caster+cast_forward()*BEAM_RANGE
	else:
		sword=spawn("guard_sword",caster+ORBIT_CENTER,1,6.3)
		sort_at_ground(sword,caster)
		trail_glow=line(12,Color(0.73,0.85,1,0.34),2)
		trail=line(1.5,Color(0.79,0.90,1,0.72),2)
		trail.width_curve=Curve.new()
		trail.width_curve.add_point(Vector2(0,0))
		trail.width_curve.add_point(Vector2(1,1))
		# shortcut: a visible training dart, not an NPC attack/AI system.
		dart=line(2,Color(0.78,0.46,0.26),3)
		dart.visible=false


func set_glow_enabled(enabled:bool) -> void:
	super.set_glow_enabled(enabled)
	for glow in [beam_glow,trail_glow]:
		if is_instance_valid(glow):glow.visible=enabled


func try_move_target(_step:Vector2) -> void:
	pass


func cast_forward() -> Vector2:
	if world != null and "caster_facing" in world:
		return {"south":Vector2.DOWN,"north":Vector2.UP,"west":Vector2.LEFT,"east":Vector2.RIGHT}.get(world.caster_facing,Vector2.RIGHT)
	return Vector2.RIGHT


func ground_offset(offset:Vector2) -> Vector2:
	return offset.rotated(cast_forward().angle())


func wall_endpoint() -> Vector2:
	var result:Vector2=world.trace_endpoint(caster,beam_end)
	wall_stopped=result.distance_to(beam_end)>0.01
	return result


func release_beam() -> void:
	released=true
	stage="pierce"
	beam_end=wall_endpoint()
	var length:float=(beam_end-caster).dot(cast_forward())
	for index in range(world.training.dummies.size()):
		var dummy:Node2D=world.training.dummies[index]
		var offset:Vector2=dummy.position-caster
		if dummy.visible and offset.dot(cast_forward())>24 and offset.dot(cast_forward())<length and absf(offset.dot(cast_forward().orthogonal()))<=22:
			world.training.hit(dummy,42,false)
			pierced.append(index)
			hit_count+=1
			spawn("impact",dummy.position+Vector2(0,-52),1.25,0.6)
			spawn("hit_star",dummy.position+Vector2(0,-52),2.0 if index==1 else 1.2,0.5)
	var flash:=spawn("projectile",caster.lerp(beam_end,0.5)+Vector2(0,-52),1,0.65)
	flash.modulate.a=0.8
	flash.rotation=cast_forward().angle()


func curve(a:Vector2,control:Vector2,b:Vector2,t:float) -> Vector2:
	return a.lerp(control,t).lerp(control.lerp(b,t),t)


func update_orbit(delta:float) -> void:
	var center:Vector2=caster+ORBIT_CENTER
	var previous:Vector2=sword.global_position
	var position_now:Vector2
	if not deflected:
		stage="guard"
		var theta:float=-TAU+elapsed*TAU/GUARD_PERIOD+cast_forward().angle()
		position_now=center+Vector2(cos(theta),sin(theta))*ORBIT_RADIUS
		sword.rotation=Vector2(-sin(theta)*104,cos(theta)*62).angle()-PI/2
		if send_mock_dart and elapsed>=2.15:
			var start:Vector2=target.position+Vector2(0,-52)
			var finish:Vector2=center+cast_forward()*ORBIT_RADIUS
			var progress:float=clampf((elapsed-2.15)/1.05,0,1.3)
			var dart_at:Vector2=start.lerp(finish,progress)
			var velocity:Vector2=(finish-start).normalized()
			dart.visible=true
			dart.points=PackedVector2Array([dart_at-velocity*14,dart_at+velocity*3])
			var previous_progress:float=clampf((elapsed-delta-2.15)/1.05,0,1.3)
			var closest:Vector2=Geometry2D.get_closest_point_to_segment(position_now,start.lerp(finish,previous_progress),dart_at)
			if position_now.distance_to(closest)<26:
				deflected=true
				deflect_time=elapsed
				attack_start=position_now
				attack_end=target.position+Vector2(0,-52)
				punishments_fired=1
				spawn("impact",position_now,0.75,0.45)
				spawn("hit_star",position_now,0.8,0.5)
	else:
		var age:float=elapsed-deflect_time
		var dart_at:Vector2=attack_start+Vector2(180,-240)*age
		dart.points=PackedVector2Array([dart_at-Vector2(9,-12),dart_at])
		dart.modulate.a=clampf(1-age/0.4,0,1)
		if age<0.14:
			stage="deflect"
			position_now=attack_start
		elif age<0.82:
			stage="counter"
			var t:float=(age-0.14)/0.68
			position_now=curve(attack_start,attack_start.lerp(attack_end,0.5)+Vector2(0,-105),attack_end,t)
		else:
			if not released:
				released=true
				if target.position.distance_to(attack_end-Vector2(0,-52))<32 and not world.training.blocked(caster,target):
					world.training.hit(target,34,false)
					hit_count=1
					spawn("impact",attack_end,1.30,0.6)
					spawn("hit_star",attack_end,1.45,0.5)
			stage="return"
			position_now=curve(attack_end,center+ground_offset(Vector2(150,85)),center+ground_offset(Vector2(24,8)),clampf((age-0.82)/0.85,0,1))
			if age>=1.67:sword.modulate.a=clampf(1-(age-1.67)/0.25,0,1)
		if position_now.distance_to(previous)>0.1:sword.rotation=(position_now-previous).angle()-PI/2
	sword.get_parent().position=position_now+Vector2(0,55)
	sword.global_position=position_now.round()
	sword.visible=elapsed>=0.25
	if elapsed>0.25:
		trail_points.append(position_now)
		trail_times.append(elapsed)
		var persistence:float=1.35 if not deflected else 0.38
		while not trail_times.is_empty() and elapsed-trail_times[0]>persistence:
			trail_times.pop_front()
			trail_points.pop_front()
		trail.points=PackedVector2Array(trail_points)
		trail_glow.points=trail.points
		trail.modulate.a=sword.modulate.a
		trail_glow.modulate.a=sword.modulate.a
	trail_glow.visible=glow_enabled
	if elapsed>=6.2 or (deflected and elapsed-deflect_time>=1.95):clear()


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	if mode=="beam":
		if elapsed>=RELEASE and not released:release_beam()
		if released:
			var age:float=elapsed-RELEASE
			var start:Vector2=caster+cast_forward()*26+Vector2(0,-52)
			var finish:Vector2=beam_end+Vector2(0,-52)
			beam.points=PackedVector2Array([start,start.lerp(finish,clampf(age/0.075,0,1))])
			beam_glow.points=beam.points
			beam.modulate.a=clampf(1-(age-0.12)/0.45,0,1)
			beam_glow.modulate.a=beam.modulate.a
			beam_glow.visible=glow_enabled
		if elapsed>1.8:clear()
	else:update_orbit(delta)
	update_pieces()


func update_pieces() -> void:
	for index in range(pieces.size()-1,-1,-1):
		var piece:Dictionary=pieces[index]
		if elapsed>=piece.expires:
			piece.container.queue_free()
			pieces.remove_at(index)
		else:
			var time:float=piece.get("clip_time",elapsed-piece.born)
			var records:Array=skill.phases[piece.phase].frames
			var selected:int=records.size()-1
			for frame in range(records.size()):
				if time<float(records[frame].duration):
					selected=frame
					break
				time-=float(records[frame].duration)
			piece.node.frame=selected
			piece.node.modulate.a=minf(piece.node.modulate.a,clampf((piece.expires-elapsed)/0.18,0,1))
			piece.glow.material.set_shader_parameter("opacity",piece.node.modulate.a)
