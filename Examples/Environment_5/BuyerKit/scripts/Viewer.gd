extends Node2D

const IDS=["City","Forest","Snow","Swamp","Desert"]
var maps:Array[Node2D]=[]
var actor:CharacterBody2D
var camera:Camera2D
var current:=0
var overview:=false
var help:Label
var data:Array

func _ready() -> void:
	y_sort_enabled=true;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	data=JSON.parse_string(FileAccess.get_file_as_string("res://BuyerKit/data/catalog.json"))
	actor=CharacterBody2D.new();actor.name="TestWalker";actor.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var collider:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=7;collider.shape=circle;collider.position=Vector2(0,-5);actor.add_child(collider)
	actor.set_script(load("res://BuyerKit/scripts/Walker.gd"));add_child(actor)
	for row in data:
		var map:Node2D=load("res://BuyerKit/maps/"+row.id+".tscn").instantiate()
		map.position=Vector2(row.origin[0],row.origin[1]);set_noise_origin(map)
		add_child(map);maps.append(map);map.visible=false
		if map.has_method("bind_actor"):map.bind_actor(actor)
	camera=Camera2D.new();add_child(camera)
	var ui:=CanvasLayer.new();add_child(ui);help=Label.new();help.position=Vector2(16,16)
	help.add_theme_font_size_override("font_size",20);help.add_theme_constant_override("outline_size",6);ui.add_child(help)
	select_map(0)
func select_map(index:int) -> void:
	current=index
	for i in range(maps.size()):
		maps[i].visible=i==index;maps[i].process_mode=Node.PROCESS_MODE_INHERIT if i==index else Node.PROCESS_MODE_DISABLED
		# Hidden maps must not leave their physics bodies active in the same local coordinates.
		set_collision(maps[i],i==index)
	var row:Dictionary=data[index];actor.position=Vector2(row.spawn[0],row.spawn[1])
	actor.velocity=Vector2.ZERO
	help.text="%s | WASD / arrows: walk | 1-5: maps | M: overview | T: terrain painter | F9: environment motion"%row.id
	update_camera()

func set_collision(node:Node,enabled:bool) -> void:
	if node is CollisionObject2D:
		if not node.has_meta("original_layer"):node.set_meta("original_layer",node.collision_layer)
		node.collision_layer=int(node.get_meta("original_layer")) if enabled else 0
	for child in node.get_children():set_collision(child,enabled)

func set_noise_origin(node:Node) -> void:
	if node is CanvasItem and node.material is ShaderMaterial and node.material.shader.resource_path.ends_with("BuyerKit/scripts/SnowPowder.gdshader"):
		node.material=node.material.duplicate();node.material.set_shader_parameter("source_origin",Vector2.ZERO)
	for child in node.get_children():set_noise_origin(child)

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode>=KEY_1 and event.keycode<=KEY_5:select_map(event.keycode-KEY_1)
	elif event.keycode==KEY_M:overview=not overview;update_camera()
	elif event.keycode==KEY_T:get_tree().change_scene_to_file("res://BuyerKit/TerrainLab.tscn")

func _process(_delta:float) -> void:
	update_camera()

func update_camera() -> void:
	var size:=Vector2(data[current].size[0],data[current].size[1])
	var origin:=Vector2(data[current].origin[0],data[current].origin[1])
	camera.limit_enabled=not overview;camera.limit_left=int(origin.x);camera.limit_top=int(origin.y);camera.limit_right=int(origin.x+size.x);camera.limit_bottom=int(origin.y+size.y)
	camera.position=origin+size/2 if overview else actor.position+Vector2(0,-100)
	camera.zoom=Vector2.ONE*(0.25 if overview else 1.0)
