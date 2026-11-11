extends Node

const WATER = preload("Water.gdshader")
const WIND = preload("Wind.gdshader")
const LANTERN = preload("Lantern.gdshader")
const GLOW = preload("Glow.gdshader")
const VIEWS = [["城镇河岸",Vector2(2256,2432)],["街巷灯火",Vector2(1736,2192)],
	["山林竹径",Vector2(1110,4510)],["雪山溪流",Vector2(6820,1600)],
	["沼泽栈道",Vector2(-1500,1780)],["沙漠绿洲",Vector2(2870,7610)]]
var entries:Array[Dictionary] = []
var glows:Array[CanvasItem] = []
var enabled := true
var view_index := -1
var hint:Label
var texture_tops:Dictionary = {}

func _ready() -> void:
	set_meta("environment_motion_controller",true)
	visit(get_parent())
	if "sect_control" in get_parent():call_deferred("town_ready")

func visit(node:Node) -> void:
	# Prefabs can already own a controller; adopt its materials instead of stacking effects or F9 handlers.
	for child in node.get_children():
		if child!=self and child.has_meta("environment_motion_controller"):
			entries.append_array(child.entries);glows.append_array(child.glows)
			child.set_process_unhandled_key_input(false);return
	if node is CanvasItem and (node.has_meta("environment_water") or (node is Polygon2D and (String(node.name) in ["RiverWater","ColdStream","IcePool","SwampWater","RiverToOasis"] or String(node.get_parent().name)=="MeanderingStoneCanal"))):
		water(node)
	if node is Sprite2D and node.get_parent().has_meta("environment_kind"):
		var kind:String = node.get_parent().get_meta("environment_kind")
		if kind in ["broadleaf_tree","broadleaf_tree_medium","road_tree","road_tree_small","willow_tree","pine_tree","bamboo","willow","broadleaf","pine_a","pine_b","poplar","reeds","shrub"] or kind.begins_with("oak_"):
			wind(node,kind)
		elif kind in ["standing_lantern","stone_lantern"]:lantern(node,kind)
		elif kind=="lotus_pond":water(node,true)
	for child in node.get_children():
		if child!=self and not child.name=="EnvironmentGlow":visit(child)

func assign(target:CanvasItem,shader:Shader,kind:String) -> ShaderMaterial:
	var material := ShaderMaterial.new();material.shader = shader
	entries.append({"target":target,"original":target.material,"material":material,"kind":kind})
	target.material = material
	return material

func water(target:CanvasItem,composite:bool=false) -> void:
	var material := assign(target,WATER,"water")
	material.set_shader_parameter("composite",composite)
	var title := String(target.name)
	material.set_shader_parameter("marsh",title=="SwampWater")
	material.set_shader_parameter("speed",0.24 if title=="SwampWater" else 0.38 if title in ["ColdStream","IcePool"] else 0.8)

func wind(sprite:Sprite2D,kind:String) -> void:
	var rect := Rect2(Vector2.ZERO,sprite.texture.get_size());var atlas := sprite.texture.get_size()
	if sprite.texture is AtlasTexture:
		rect = sprite.texture.region;atlas = sprite.texture.atlas.get_size()
	var material := assign(sprite,WIND,"wind")
	material.set_shader_parameter("region_px",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	material.set_shader_parameter("atlas_size",atlas)
	material.set_shader_parameter("anchor_y",-sprite.position.y)
	var key := str(sprite.texture.get_rid())
	if sprite.texture is AtlasTexture:key = str(sprite.texture.atlas.get_rid())+str(rect)
	if not texture_tops.has(key):
		var image := sprite.texture.get_image()
		if image.is_compressed():image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var pixels := image.get_data();var first := 0
		for i in range(3,pixels.size(),4):
			if pixels[i]>=141:first = floori(float(i)/4/image.get_width());break
		texture_tops[key] = first
	material.set_shader_parameter("top_y",texture_tops[key])
	material.set_shader_parameter("phase",fposmod(sprite.global_position.x*0.017+sprite.global_position.y*0.023,TAU))
	material.set_shader_parameter("amplitude",4.0 if kind in ["bamboo","willow","willow_tree","reeds"] else 3.0)
	var previous:Material = entries[-1].original
	if previous is ShaderMaterial and previous.shader.resource_path.ends_with("CountrysideCutout.gdshader"):
		material.set_shader_parameter("alpha_cutoff",0.55)

func lantern(sprite:Sprite2D,kind:String) -> void:
	var phase := fposmod(sprite.global_position.x*0.017+sprite.global_position.y*0.023,TAU)
	var material := assign(sprite,LANTERN,"lantern");material.set_shader_parameter("phase",phase)
	var center := Vector2(63,81)
	if kind=="stone_lantern":
		center = Vector2(65,86);material.set_shader_parameter("window_px",Vector4(57,80,15,12))
	var halo := Polygon2D.new();halo.name = "EnvironmentGlow";halo.z_index = -1
	halo.position = sprite.position+center
	halo.polygon = PackedVector2Array([Vector2(-48,-36),Vector2(48,-36),Vector2(48,36),Vector2(-48,36)])
	halo.uv = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	sprite.get_parent().add_child(halo);glows.append(halo)
	material = ShaderMaterial.new();material.shader = GLOW;material.set_shader_parameter("phase",phase);halo.material = material

func set_enabled(value:bool) -> void:
	enabled = value
	for entry in entries:entry.target.material = entry.material if enabled else entry.original
	for halo in glows:halo.visible = enabled
	refresh_hint()

func set_time(value:float) -> void:
	for entry in entries:entry.material.set_shader_parameter("motion_time",value)
	for halo in glows:halo.material.set_shader_parameter("motion_time",value)

func town_ready() -> void:
	var world := get_parent()
	for tick in range(600):
		if world.sect_control!=null and world.sect_control.control_ready:break
		await get_tree().process_frame
	if world.sect_control==null:return
	var layer := CanvasLayer.new();layer.layer = 44;add_child(layer)
	hint = Label.new();hint.position = Vector2(24,900)
	hint.add_theme_font_override("font",load("res://assets/fonts/SourceHanSerifCN-Regular.otf"));hint.add_theme_font_size_override("font_size",18)
	hint.add_theme_color_override("font_color",Color("ecdcb7"));hint.add_theme_color_override("font_outline_color",Color("1b2119"));hint.add_theme_constant_override("outline_size",6)
	layer.add_child(hint);refresh_hint()
	if OS.get_cmdline_user_args().has("--environment-start"):next_view()

func next_view() -> void:
	var world := get_parent()
	if not "sect_control" in world or world.sect_control==null:return
	view_index = (view_index+1)%VIEWS.size()
	world.sect_control.skills.cancel();world.player.velocity = Vector2.ZERO;world.player.position = VIEWS[view_index][1]
	world.overview = false;world.freeze_camera = false;world.camera.reset_smoothing()
	refresh_hint()

func refresh_hint() -> void:
	if hint!=null:hint.text = "环境动态：%s · F9 动态/静态对比 · F10 下一观景点%s"%["开启" if enabled else "关闭"," · "+VIEWS[view_index][0] if view_index>=0 else ""]

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_F9:set_enabled(not enabled);get_viewport().set_input_as_handled()
	elif event.keycode==KEY_F10 and "sect_control" in get_parent():next_view();get_viewport().set_input_as_handled()
