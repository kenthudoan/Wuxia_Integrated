extends Control

signal return_to_town
@export var town_mode := false
var pages:Array[Control] = []
var tabs:Array[Button] = []
var selected := 0
var container:PanelContainer

func _ready() -> void:
	theme = load("res://UI/wuxia_theme.tres");texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font:FontFile = theme.default_font;font.allow_system_fallback = false
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE;font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var background := ColorRect.new();background.color = Color("111a1d");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(background)
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
	add_child(margin)
	var root := VBoxContainer.new();root.add_theme_constant_override("separation",16);margin.add_child(root)
	var heading := HBoxContainer.new();root.add_child(heading)
	var title := Label.new();title.text = "武林 · 界面图鉴";title.add_theme_font_size_override("font_size",34);title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;heading.add_child(title)
	if town_mode:
		var back := Button.new();back.text = "F2 返回城镇";back.pressed.connect(func():return_to_town.emit());heading.add_child(back)
	var note := Label.new();note.text = "物品、任务与冷却使用展示数据；音量设置控制实际声音。";note.add_theme_font_size_override("font_size",18);root.add_child(note)
	var nav := HBoxContainer.new();nav.add_theme_constant_override("separation",12);root.add_child(nav)
	var names := ["组件与状态","行囊物品","门派武学","对话任务","音效设置","小地图","装备","商店"]
	var group := ButtonGroup.new()
	for index in range(names.size()):
		var button := Button.new();button.text = names[index];button.toggle_mode = true;button.button_group = group;button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y = 54
		button.pressed.connect(select.bind(index));nav.add_child(button);tabs.append(button)
	container = PanelContainer.new();container.size_flags_vertical = Control.SIZE_EXPAND_FILL;root.add_child(container)
	for index in range(names.size()):
		var page:Control = load("res://UI/prefabs/"+["Components","Inventory","Skills","DialogueTasks","Settings","MiniMap","Equipment","Shop"][index]+".tscn").instantiate()
		page.navigate.connect(select);container.add_child(page);pages.append(page)
	select(0)

func select(index:int) -> void:
	selected = index
	for i in range(pages.size()):pages[i].visible = i==index;tabs[i].button_pressed = i==index

func _input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if town_mode and event.keycode in [KEY_F2,KEY_F7]:
		get_viewport().set_input_as_handled();return_to_town.emit()

func _unhandled_key_input(event:InputEvent) -> void:
	if not town_mode and event.is_action_pressed("ui_cancel"):get_tree().quit()
