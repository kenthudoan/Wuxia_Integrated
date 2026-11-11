extends VBoxContainer

signal changed(value:Variant)
signal activated(action:String)
@export_enum("Slider","Dropdown","Tooltip","TabNavigation","Pagination","InventoryGrid","ItemDetails","DialogueBox","TaskEntry","MiniMapDisplay","WindowHeader","ScrollingList","SearchField","QuantitySelector","EquipmentSlots","ShopItemRow","ConfirmationModal","StatusEffectBar","ToastMessage","Hotbar") var kind := 0
@export var data:Dictionary = {}
var primary:Control
var secondary:Control
var grid:GridContainer
var buttons:Array[Button] = []
var selected := 0
var spin:SpinBox
var dialog:ConfirmationDialog
var effect_labels:Array[Label] = []
var message_timer:Timer
var hotbar_keys:Array[String] = []

func _ready() -> void:
	theme = load("res://UI/wuxia_theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override("separation",10)
	build()

func configure(values:Dictionary) -> void:
	data = values.duplicate(true)
	if is_node_ready():
		for child in get_children():child.free()
		buttons.clear();effect_labels.clear();hotbar_keys.clear();primary = null;secondary = null;grid = null;spin = null;dialog = null;message_timer = null
		build()

func text(value:String,parent:Node=null) -> Label:
	var node := Label.new();node.text = value;node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent!=null else self).add_child(node)
	return node

func row(parent:Node=null) -> HBoxContainer:
	var node := HBoxContainer.new();node.add_theme_constant_override("separation",10)
	(parent if parent!=null else self).add_child(node);return node

func button(title:String,action:Callable,parent:Node=null) -> Button:
	var node := Button.new();node.text = title;node.custom_minimum_size = Vector2(76,44)
	node.pressed.connect(action);(parent if parent!=null else self).add_child(node);buttons.append(node)
	return node

func slot(item:Dictionary,parent:Node) -> Button:
	var node := Button.new();node.set_script(load("res://UI/IconSlot.gd"));node.custom_minimum_size = Vector2(80,80)
	var path:String = item.get("icon","")
	if not path.is_empty():node.artwork = load(path)
	node.quantity = int(item.get("count",0));node.tooltip_text = item.get("name","")
	parent.add_child(node);buttons.append(node);return node

func build() -> void:
	match kind:
		0:
			var node := HSlider.new();node.min_value = data.get("min",0);node.max_value = maxf(node.min_value,data.get("max",100))
			node.value = data.get("value",50);node.step = data.get("step",1);node.editable = not data.get("disabled",false)
			node.custom_minimum_size = Vector2(240,44);node.value_changed.connect(func(value:float):changed.emit(value));add_child(node);primary = node
		1:
			var node := OptionButton.new();node.custom_minimum_size.y = 48
			for title in data.get("options",["全部","兵器","药品"]):node.add_item(str(title))
			for index in data.get("disabled_options",[]):
				if index>=0 and index<node.item_count:node.set_item_disabled(index,true)
			node.disabled = data.get("disabled",false);node.item_selected.connect(func(index:int):selected = index;changed.emit(index));add_child(node);primary = node
		2:
			var panel := PanelContainer.new();panel.theme_type_variation = "PaperPanel";add_child(panel)
			var content := VBoxContainer.new();panel.add_child(content)
			for value in [data.get("title","青锋剑"),data.get("body","百炼青锋，剑脊含光。长文字在固定宽度内自动换行，不烘焙进底图。")]:
				var line := text(str(value),content);line.theme_type_variation = "InkLabel";line.custom_minimum_size.x = data.get("width",320)
			primary = panel
		3:
			var nav := row();var group := ButtonGroup.new();var titles:Array = data.get("tabs",["全部","兵器","药品"])
			selected = clampi(int(data.get("selected",0)),0,maxi(titles.size()-1,0))
			for i in range(titles.size()):
				var index := i;var node := button(str(titles[i]),func():select_tab(index),nav)
				node.toggle_mode = true;node.button_group = group;node.disabled = i in data.get("disabled_tabs",[]);node.button_pressed = i==selected
		4:
			var nav := row();selected = clampi(int(data.get("page",0)),0,maxi(int(data.get("pages",3))-1,0))
			button("上一页",func():set_page(selected-1),nav);primary = text("",nav)
			button("下一页",func():set_page(selected+1),nav);update_paging()
		5:
			grid = GridContainer.new();grid.columns = maxi(int(data.get("columns",4)),1);add_child(grid)
			var entries:Array = data.get("items",[]);selected = int(data.get("selected",-1))
			for i in range(maxi(int(data.get("capacity",8)),entries.size())):
				var item:Dictionary = entries[i] if i<entries.size() else {};var index := i
				var node := slot(item,grid);node.disabled = item.is_empty() or int(item.get("count",1))<=0;node.selected = i==selected
				node.pressed.connect(func():select_slot(index))
		6:
			text(str(data.get("name","青锋剑")))
			text(str(data.get("description","百炼青锋，剑脊含光。")))
			var attributes:Dictionary = data.get("attributes",{"攻击":"+18","品质":"精良"})
			for key in attributes:
				var line := row();text(str(key),line);text(str(attributes[key]),line)
		7:
			var body := row();var portrait := TextureRect.new();portrait.custom_minimum_size = Vector2(80,80)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var path:String = data.get("portrait","res://UI/portraits/portrait.png")
			if not path.is_empty():portrait.texture = load(path)
			portrait.visible = portrait.texture!=null;body.add_child(portrait);primary = portrait
			var content := VBoxContainer.new();content.size_flags_horizontal = Control.SIZE_EXPAND_FILL;body.add_child(content)
			text(str(data.get("speaker","客栈掌柜")),content);text(str(data.get("body","此去江湖，山水迢迢。")),content)
			var options := row()
			for choice in data.get("options",["继续交谈","告辞"]):
				var value:String = str(choice);button(value,func():activated.emit(value),options)
		8:
			var check := CheckBox.new();check.text = str(data.get("title","行前准备"));check.button_pressed = data.get("complete",false)
			check.toggled.connect(func(value:bool):changed.emit(value));add_child(check);primary = check
			var progress := ProgressBar.new();progress.max_value = maxf(float(data.get("total",3)),1);progress.value = data.get("progress",1)
			progress.custom_minimum_size.y = 28;add_child(progress);secondary = progress
		9:
			var node := Control.new();node.set_script(load("res://UI/MiniMap.gd"));node.custom_minimum_size = Vector2(320,240)
			node.use_town_markers = not data.has("markers");node.markers = data.get("markers",[])
			var at:Array = data.get("position",[1616,2192]);node.player_position = Vector2(at[0],at[1]);add_child(node);primary = node
		10:
			var header := row();button("返回",func():activated.emit("back"),header)
			primary = text(str(data.get("title","江湖行囊")),header);button("关闭",func():activated.emit("close"),header)
		11:
			var scroll := ScrollContainer.new();scroll.custom_minimum_size = Vector2(240,220);scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll);primary = scroll
			var content := VBoxContainer.new();content.size_flags_horizontal = Control.SIZE_EXPAND_FILL;scroll.add_child(content);secondary = content
			var entries:Array = data.get("items",[])
			if entries.is_empty():text(str(data.get("empty_text","暂无条目")),content)
			for i in range(entries.size()):
				var index := i;button(str(entries[i]),func():selected = index;changed.emit(index),content)
		12:
			var search := row();var field := LineEdit.new();field.placeholder_text = str(data.get("placeholder","搜索物品"))
			field.text = str(data.get("query",""));field.editable = not data.get("disabled",false);field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			field.custom_minimum_size = Vector2(220,48);search.add_child(field);primary = field
			var clear := button("清除",func():field.clear();field.grab_focus(),search);secondary = clear
			field.text_changed.connect(func(value:String):clear.disabled = not field.editable or value.is_empty();changed.emit(value))
			clear.disabled = not field.editable or field.text.is_empty()
		13:
			var amount := row();spin = SpinBox.new();spin.min_value = data.get("min",1);spin.max_value = maxf(spin.min_value,data.get("max",99));spin.step = 1
			spin.value = data.get("value",spin.min_value);spin.custom_minimum_size = Vector2(110,44);spin.editable = not data.get("disabled",false)
			button("−",func():set_quantity(spin.value-1),amount);amount.add_child(spin);primary = spin
			button("+",func():set_quantity(spin.value+1),amount)
			spin.value_changed.connect(func(value:float):update_quantity();changed.emit(int(value)));update_quantity()
		14:
			grid = GridContainer.new();grid.columns = 3;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",12);add_child(grid)
			var entries:Array = data.get("slots",[{"name":"武器"},{"name":"衣物"},{"name":"头部"},{"name":"鞋子"},{"name":"饰物"}])
			selected = int(data.get("selected",0))
			for i in range(entries.size()):
				var item:Dictionary = entries[i];var index := i;var content := VBoxContainer.new();grid.add_child(content)
				var node := slot(item,content);node.selected = i==selected;node.pressed.connect(func():select_slot(index));text(str(item.get("name","空槽")),content)
		15:
			var line := row();slot(data,line);var content := VBoxContainer.new();content.custom_minimum_size.x = 220;content.size_flags_horizontal = Control.SIZE_EXPAND_FILL;line.add_child(content)
			text(str(data.get("name","金创药")),content);text("单价 %d · 库存 %d · 持有 %d"%[int(data.get("price",20)),int(data.get("stock",5)),int(data.get("owned",0))],content)
			var amount:Control = load("res://UI/prefabs/QuantitySelector.tscn").instantiate();amount.data = {"min":1,"max":maxi(maxi(int(data.get("stock",5)),int(data.get("owned",0))),1)};line.add_child(amount);primary = amount
			button("购买",func():activated.emit("buy"),line).disabled = int(data.get("stock",5))<=0
			button("售出",func():activated.emit("sell"),line).disabled = int(data.get("owned",0))<=0
		16:
			button(str(data.get("button","打开确认弹窗")),open_confirmation)
			dialog = ConfirmationDialog.new();dialog.theme = theme;dialog.title = str(data.get("title","确认操作"));dialog.dialog_text = str(data.get("body","此操作仅改变展示数据。"))
			dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;dialog.get_label().custom_minimum_size.x = 440
			dialog.ok_button_text = "确认";dialog.cancel_button_text = "取消";dialog.confirmed.connect(func():activated.emit("confirm"));dialog.canceled.connect(func():activated.emit("cancel"));add_child(dialog)
		17:
			if not data.has("effects"):data["effects"] = [{"name":"护体","icon":"res://UI/icons/items/potion.png","remaining":90.0,"layers":2},{"name":"轻身","icon":"res://UI/icons/items/herb.png","remaining":45.0,"layers":1}]
			var effects := HFlowContainer.new();effects.add_theme_constant_override("h_separation",16);add_child(effects);primary = effects
			if data.effects.is_empty():text("暂无状态效果",effects)
			for effect in data.effects:
				effect.remaining = maxf(float(effect.get("remaining",0)),0)
				var content := VBoxContainer.new();effects.add_child(content)
				var icon := slot({"name":effect.get("name","状态"),"icon":effect.get("icon",""),"count":maxi(int(effect.get("layers",1)),1)},content)
				icon.focus_mode = Control.FOCUS_NONE
				var timer_label := text("%ds"%ceili(effect.remaining),content);effect_labels.append(timer_label)
		18:
			var panel := PanelContainer.new();panel.theme_type_variation = "PaperPanel";add_child(panel);primary = panel
			var message := text("",panel);message.theme_type_variation = "InkLabel";secondary = message
			message_timer = Timer.new();message_timer.one_shot = true;add_child(message_timer)
			message_timer.timeout.connect(func():primary.hide();activated.emit("expired"))
			show_message(str(data.get("message","拾取：铁矿 × 1")),str(data.get("severity","info")),float(data.get("seconds",3)))
		19:
			var bar := row();primary = bar
			var entries:Array = data.get("slots",[{"name":"招式一","icon":"res://UI/icons/items/sword.png","key":"1"},{"name":"招式二","icon":"res://UI/icons/items/scroll.png","key":"2"},{"name":"药品","icon":"res://UI/icons/items/potion.png","key":"3"}])
			selected = clampi(int(data.get("selected",0)),0,maxi(entries.size()-1,0))
			for i in range(entries.size()):
				var item:Dictionary = entries[i];var index := i;var content := VBoxContainer.new();bar.add_child(content)
				var node := slot(item,content);node.selected = i==selected;node.disabled = item.get("disabled",false)
				node.pressed.connect(func():activate_hotbar(index));hotbar_keys.append(str(item.get("key",str(i+1))))
				var hint := text(hotbar_keys[-1]+" · "+str(item.get("name","招式")),content);hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta:float) -> void:
	if kind==17:advance_effects(delta)

func advance_effects(delta:float) -> void:
	if not data.has("effects"):return
	var expired := false
	for i in range(data.effects.size()):
		var effect:Dictionary = data.effects[i];effect.remaining = maxf(0,float(effect.remaining)-maxf(delta,0))
		expired = expired or effect.remaining<=0
		if i<effect_labels.size():effect_labels[i].text = "%ds"%ceili(effect.remaining)
	if expired:
		var remaining:Array = data.effects.filter(func(effect):return effect.remaining>0)
		configure({"effects":remaining})

func show_message(message:String,severity:String="info",seconds:float=3.0) -> void:
	secondary.text = message;secondary.modulate = Color("7e2826") if severity=="error" else Color("304b30") if severity=="success" else Color.WHITE
	primary.show();message_timer.start(maxf(seconds,.05))

func activate_hotbar(index:int) -> void:
	if index<0 or index>=buttons.size() or buttons[index].disabled:return
	select_slot(index)
	var entries:Array = data.get("slots",[])
	buttons[index].start_cooldown(float(entries[index].get("cooldown",3.0)) if index<entries.size() else 3.0)
	activated.emit(str(index))

func _unhandled_key_input(event:InputEvent) -> void:
	if kind!=19 or not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:return
	for i in range(hotbar_keys.size()):
		if event.keycode==OS.find_keycode_from_string(hotbar_keys[i]):
			activate_hotbar(i);get_viewport().set_input_as_handled();return

func select_tab(index:int) -> void:
	if index<0 or index>=buttons.size() or buttons[index].disabled:return
	selected = index
	for i in range(buttons.size()):buttons[i].button_pressed = i==selected
	changed.emit(index)

func set_page(index:int) -> void:
	selected = clampi(index,0,maxi(int(data.get("pages",3))-1,0));update_paging();changed.emit(selected)

func update_paging() -> void:
	var pages := maxi(int(data.get("pages",3)),1)
	primary.text = "%d / %d"%[selected+1,pages];buttons[0].disabled = selected==0;buttons[1].disabled = selected==pages-1

func select_slot(index:int) -> void:
	if index<0 or index>=buttons.size() or buttons[index].disabled:return
	selected = index
	for i in range(buttons.size()):buttons[i].selected = i==selected;buttons[i].queue_redraw()
	changed.emit(index)

func set_quantity(value:float) -> void:
	spin.value = clampf(value,spin.min_value,spin.max_value)

func update_quantity() -> void:
	buttons[0].disabled = not spin.editable or spin.value<=spin.min_value
	buttons[1].disabled = not spin.editable or spin.value>=spin.max_value

func open_confirmation() -> void:
	dialog.popup_centered(Vector2i(540,250));dialog.get_cancel_button().grab_focus()
