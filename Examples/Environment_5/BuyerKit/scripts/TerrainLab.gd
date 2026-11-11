extends Node2D

const DIR = "res://BuyerKit/terrain/connected/"
const OFFSET = Vector2(32,192)
const AREA = Rect2i(0,0,23,12)
var catalog:Array
var current := 0
var example:Node2D
var terrain:TileMapLayer
var actor:CharacterBody2D
var selector:OptionButton
var hint:Label
var grid := false
var last_cell := Vector2i(-999,-999)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	catalog = JSON.parse_string(FileAccess.get_file_as_string(DIR+"catalog.json")).pairs
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color("18272b");panel.size = Vector2(1536,168);ui.add_child(panel)
	var title := Label.new()
	title.position = Vector2(32,18);title.text = "WUXIA  /  CONNECTED TERRAIN";title.add_theme_font_size_override("font_size",26);ui.add_child(title)
	selector = OptionButton.new()
	selector.position = Vector2(32,65);selector.size = Vector2(330,42)
	for row in catalog:selector.add_item(row.id.replace("_"," / "))
	selector.item_selected.connect(select_pair);ui.add_child(selector)
	for row in [["Reset example",392,reset],["Clear",580,clear],["Grid",705,toggle_grid],["Return to maps",830,back]]:
		var button := Button.new()
		button.position = Vector2(row[1],65);button.size = Vector2(160 if row[0]!="Grid" and row[0]!="Clear" else 100,42)
		button.text = row[0];button.pressed.connect(row[2]);ui.add_child(button)
	hint = Label.new()
	hint.position = Vector2(32,122);hint.add_theme_font_size_override("font_size",18);ui.add_child(hint)
	var footer := Label.new()
	footer.position = Vector2(32,976);footer.text = "Left drag: paint  |  Right drag: erase  |  WASD / arrows: walk  |  N: next pair  |  1-5: biome  |  R: reset  |  G: grid  |  Esc: maps"
	footer.add_theme_font_size_override("font_size",17);ui.add_child(footer)
	actor = CharacterBody2D.new()
	actor.set_script(load("res://BuyerKit/scripts/Walker.gd"));actor.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new();shape.radius = 7;collider.shape = shape;collider.position = Vector2(0,-5);actor.add_child(collider)
	actor.z_index = 2;add_child(actor)
	select_pair(0)
func select_pair(index:int) -> void:
	current = index;selector.select(index)
	if is_instance_valid(example):
		remove_child(example);example.queue_free()
	example = load(DIR+catalog[index].id+"_example.tscn").instantiate()
	example.position = OFFSET;add_child(example);move_child(example,0)
	terrain = example.get_node("Terrain")
	actor.position = OFFSET+Vector2(96,288);actor.velocity = Vector2.ZERO
	var water:bool = catalog[index].water_collision
	hint.text = "64 px tiles  |  47 connection patterns x 3 texture variants  |  "+("Water blocks movement; erase to open a crossing" if water else "Road / ground: walkable")
	last_cell = Vector2i(-999,-999);queue_redraw()

func paint(cells:Array,erase:bool) -> void:
	var valid:Array[Vector2i] = []
	for cell in cells:
		if AREA.has_point(cell):valid.append(cell)
	if not valid.is_empty():terrain.set_cells_terrain_connect(valid,0,-1 if erase else 0,false)

func reset() -> void:select_pair(current)
func clear() -> void:terrain.clear()
func toggle_grid() -> void:grid = not grid;queue_redraw()
func back() -> void:get_tree().change_scene_to_file("res://BuyerKit/Viewer.tscn")

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_ESCAPE:back()
		KEY_R:reset()
		KEY_C:clear()
		KEY_G:toggle_grid()
		KEY_N:select_pair((current+1)%catalog.size())
		KEY_1,KEY_2,KEY_3,KEY_4,KEY_5:
			var biome:String = ["City","Forest","Snow","Swamp","Desert"][event.keycode-KEY_1]
			for i in range(catalog.size()):
				if catalog[i].biome==biome:select_pair(i);break

func _process(_delta:float) -> void:
	actor.position = actor.position.clamp(OFFSET+Vector2(8,18),OFFSET+Vector2(1464,760))
	var cell := terrain.local_to_map(terrain.get_local_mouse_position())
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if AREA.has_point(cell):
			var cells:Array[Vector2i] = []
			if AREA.has_point(last_cell):
				var count:int = maxi(absi(cell.x-last_cell.x),absi(cell.y-last_cell.y))
				for i in range(count+1):cells.append(Vector2i(Vector2(last_cell).lerp(Vector2(cell),float(i)/maxi(count,1)).round()))
			else:cells.append(cell)
			paint(cells,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
			last_cell = cell
		else:last_cell = Vector2i(-999,-999)
	else:last_cell = Vector2i(-999,-999)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(terrain):return
	if grid:
		for x in range(24):draw_line(OFFSET+Vector2(x*64,0),OFFSET+Vector2(x*64,768),Color(1,1,1,0.12))
		for y in range(13):draw_line(OFFSET+Vector2(0,y*64),OFFSET+Vector2(1472,y*64),Color(1,1,1,0.12))
	var cell := terrain.local_to_map(terrain.get_local_mouse_position())
	if AREA.has_point(cell):draw_rect(Rect2(OFFSET+Vector2(cell*64),Vector2(64,64)),Color(0.94,0.81,0.44,0.9),false,2)
