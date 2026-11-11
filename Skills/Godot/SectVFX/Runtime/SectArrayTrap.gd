extends Node2D

const DURATION:=12.0
const FORM_TIME:=1.55
const RADIUS:=Vector2(138,78)
const TURN_SPEED:=TAU/28.0
const WARNING_RADIUS:=0.74
const CONFINEMENT_RADIUS:=0.82
const COUNTER_COOLDOWN:=1.35
const COUNTER_FALL:=0.46
const SMALL_SCALE:=0.60
const GLOW=preload("res://SectVFX/Runtime/SectLocalGlow.gdshader")
const RING_GLOW=preload("res://SectVFX/Runtime/SectArrayRingGlow.gdshader")

var world:Node2D
var skill:Dictionary
var target:Node2D
var caster:Vector2
var array_center:=Vector2.ZERO
var elapsed:=0.0
var active:=false
var glow_enabled:=true
var hit_count:=0
var punishments_fired:=0
var missed_counters:=0
var next_counter_at:=0.0
var confinement_count:=0
var pieces:Array=[]
var guard_swords:Array=[]
var counters:Array=[]
var frame_cache:Dictionary={}
var textures:Dictionary={}
var ring:Node2D
var ring_line:Line2D
var ring_glow:Sprite2D
var white:GradientTexture2D
var facing:=Vector2.RIGHT


func direction_offset(forward:float,lateral:float=0.0) -> Vector2:
	return facing*forward+Vector2(-facing.y,facing.x)*lateral


func in_facing(offset:Vector2) -> Vector2:
	return Vector2(offset.dot(facing),offset.dot(Vector2(-facing.y,facing.x)))


func _ready() -> void:
	white=GradientTexture2D.new()
	white.width=2
	white.height=2
	white.gradient=Gradient.new()
	white.gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE])


func clear() -> void:
	active=false
	for piece in pieces:
		if is_instance_valid(piece.container):piece.container.queue_free()
	pieces.clear()
	guard_swords.clear()
	counters.clear()
	if is_instance_valid(ring):ring.queue_free()
	ring=null
	if is_instance_valid(target) and target.has_meta("array_confined"):target.remove_meta("array_confined")


func frames_for(phase:String) -> SpriteFrames:
	var data:Dictionary=skill.phases[phase]
	if frame_cache.has(data.sheet):return frame_cache[data.sheet]
	var sheet:Texture2D=load("res://"+data.sheet)
	textures[data.sheet]=sheet
	var clips:=SpriteFrames.new()
	clips.remove_animation("default")
	clips.add_animation("fx")
	clips.set_animation_speed("fx",1.0)
	clips.set_animation_loop("fx",phase=="projectile")
	for frame in data.frames:
		var atlas:=AtlasTexture.new()
		atlas.atlas=sheet
		var rect:Array=frame.rect
		atlas.region=Rect2(rect[0],rect[1],rect[2],rect[3])
		clips.add_frame("fx",atlas,float(frame.duration))
	frame_cache[data.sheet]=clips
	return clips


func spawn(phase:String, at:Vector2, size:float, life:float, z:int=2) -> AnimatedSprite2D:
	var data:Dictionary=skill.phases[phase]
	var sprite:=AnimatedSprite2D.new()
	sprite.name="Trap_"+phase
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames=frames_for(phase)
	sprite.position=at
	sprite.scale=Vector2.ONE*size
	sprite.z_index=z
	var rect:Array=data.frames[0].rect
	sprite.offset=Vector2(float(rect[2])/2-data.anchor[0],float(rect[3])/2-data.anchor[1])
	world.add_child(sprite)
	var halo:=Sprite2D.new()
	halo.name="LocalSoftGlow"
	halo.texture=white
	halo.position=sprite.offset
	halo.scale=Vector2(float(rect[2])+28,float(rect[3])+28)/2.0
	halo.show_behind_parent=true
	var material:=ShaderMaterial.new()
	material.shader=GLOW
	material.set_shader_parameter("source_texture",textures[data.sheet])
	material.set_shader_parameter("frame_rect",Vector4(rect[0],rect[1],rect[2],rect[3]))
	if skill.mode=="array" and phase=="projectile":material.set_shader_parameter("strength",.50)
	halo.material=material
	halo.visible=glow_enabled
	sprite.add_child(halo)
	sprite.frame_changed.connect(func():
		var current:Array=data.frames[sprite.frame].rect
		material.set_shader_parameter("frame_rect",Vector4(current[0],current[1],current[2],current[3])))
	pieces.append({"node":sprite,"container":sprite,"glow":halo,"born":elapsed,"expires":elapsed+life,"phase":phase})
	sprite.play("fx")
	return sprite


func sort_at_ground(sprite:AnimatedSprite2D, ground:Vector2) -> Node2D:
	# Sort the floating blade by its ground projection, not by its elevated picture center.
	var holder:=Node2D.new()
	holder.name="TrapFootSortRoot"
	holder.position=ground
	world.entities.add_child(holder)
	sprite.reparent(holder,true)
	sprite.z_index=0
	pieces[-1].container=holder
	return holder


func play(spec:Dictionary, at:Vector2, dummy:Node2D) -> void:
	clear()
	skill=spec
	assert(skill.mode=="array")
	caster=at
	target=dummy
	array_center=dummy.position
	elapsed=0
	hit_count=0
	punishments_fired=0
	missed_counters=0
	confinement_count=0
	next_counter_at=0
	active=true
	target.set_meta("array_confined",true)
	spawn("cast",caster+Vector2(0,-55),1.0,0.55)
	ring=Node2D.new()
	ring.name="StationarySwordPrison"
	ring.position=array_center
	ring.z_index=-2
	world.add_child(ring)
	ring_line=Line2D.new()
	ring_line.width=2
	ring_line.default_color=Color(0.78,0.86,1.0,0.65)
	for i in range(97):
		var theta:float=i*TAU/96
		ring_line.add_point(Vector2(cos(theta),sin(theta))*RADIUS)
	ring.add_child(ring_line)
	ring_glow=Sprite2D.new()
	ring_glow.texture=white
	ring_glow.scale=(RADIUS*2+Vector2(28,28))/2.0
	var material:=ShaderMaterial.new()
	material.shader=RING_GLOW
	material.set_shader_parameter("radius",RADIUS)
	material.set_shader_parameter("quad_size",RADIUS*2+Vector2(28,28))
	ring_glow.material=material
	ring.add_child(ring_glow)
	ring.visible=false
	for index in range(7):
		var sword:=spawn("projectile",array_center-Vector2(0,600),1.0,DURATION)
		var holder:=sort_at_ground(sword,array_center)
		sword.visible=false
		guard_swords.append({"node":sword,"holder":holder,"index":index,"delay":0.35+index*0.105,"landed":false,"root":array_center})


func rotation_angle() -> float:
	return maxf(0,elapsed-FORM_TIME)*TURN_SPEED


func set_glow_enabled(enabled:bool) -> void:
	glow_enabled=enabled
	for piece in pieces:
		if is_instance_valid(piece.glow):piece.glow.visible=enabled
	if is_instance_valid(ring_glow):ring_glow.visible=enabled


func normalized_radius(at:Vector2) -> float:
	return ((at-array_center)/RADIUS).length()


func try_move_target(step:Vector2) -> void:
	if not active or elapsed<FORM_TIME or step.is_zero_approx():return
	var before:float=normalized_radius(target.position)
	var wanted:Vector2=target.position+step
	var local:Vector2=(wanted-array_center)/RADIUS
	var distance:float=local.length()
	if distance>CONFINEMENT_RADIUS:
		wanted=array_center+local.normalized()*RADIUS*CONFINEMENT_RADIUS
		confinement_count+=1
	target.position=wanted
	if distance>=WARNING_RADIUS and distance>before+0.00001 and elapsed>=next_counter_at and elapsed<DURATION-0.8:
		launch_counter()


func launch_counter() -> void:
	if int(target.get_meta("training_hp",300))<=0:return
	var aim:Vector2=target.position
	var sword:=spawn("projectile",aim-Vector2(0,600),SMALL_SCALE,COUNTER_FALL+0.22,3)
	sort_at_ground(sword,aim)
	var end:Vector2=aim+Vector2(0,-48-57*SMALL_SCALE)
	counters.append({"node":sword,"aim":aim,"end":end,"born":elapsed,"done":false})
	punishments_fired+=1
	next_counter_at=elapsed+COUNTER_COOLDOWN
	spawn("cast",aim+Vector2(0,-3),0.7,0.35,-1)


func _process(delta:float) -> void:
	if not active:return
	elapsed+=delta
	var fade:float=clampf((DURATION-elapsed)/0.5,0,1)
	for guard in guard_swords:
		var sprite:AnimatedSprite2D=guard.node
		var age:float=elapsed-guard.delay
		sprite.visible=age>=0
		if age<0:continue
		var theta:float=-PI/2+guard.index*TAU/7.0+rotation_angle()
		var root:Vector2=array_center+Vector2(cos(theta),sin(theta))*RADIUS
		guard.root=root
		guard.holder.position=root
		var drop:float=clampf(age/0.46,0,1)
		sprite.position=Vector2(0,-57-520*(1.0-drop*drop))
		if age>=0.46:
			sprite.position.y+=roundf(sin(elapsed*3+guard.index)*1.5)
			if not guard.landed:
				guard.landed=true
				spawn("impact",root,0.65,0.5,-1)
		sprite.modulate.a=fade
	for counter in counters:
		var age:float=elapsed-counter.born
		if not is_instance_valid(counter.node):continue
		var progress:float=clampf(age/COUNTER_FALL,0,1)
		counter.node.global_position=counter.end+Vector2(0,-520*(1.0-progress*progress))
		if age>=COUNTER_FALL and not counter.done:
			counter.done=true
			if is_instance_valid(target) and target.position.distance_to(counter.aim)<=32 and not world.training.blocked(caster,target):
				world.training.hit(target,18,false)
				hit_count+=1
			else:missed_counters+=1
			spawn("impact",counter.aim+Vector2(0,-48),1.0,0.5)
			counter.node.visible=false
	for index in range(pieces.size()-1,-1,-1):
		var piece:Dictionary=pieces[index]
		if elapsed>=piece.expires:
			piece.container.queue_free()
			pieces.remove_at(index)
		else:
			piece.node.modulate.a=minf(piece.node.modulate.a,clampf((piece.expires-elapsed)/0.18,0,1))
			piece.glow.material.set_shader_parameter("opacity",piece.node.modulate.a)
	if is_instance_valid(ring):
		ring.visible=elapsed>0.65
		ring.modulate.a=clampf((elapsed-0.65)/0.8,0,1)*fade
		ring_glow.visible=glow_enabled
		ring_glow.material.set_shader_parameter("opacity",ring.modulate.a)
	if elapsed>=DURATION:clear()


func _exit_tree() -> void:
	clear()
