extends MarginContainer

signal navigate(index:int)

@export_range(0,7) var kind := 0
var box:VBoxContainer
var status:Label
var catalog:Array = []
var slots:Array[Button] = []
var item_filter := 0
var inventory := [{"name":"青锋剑","icon":"sword","type":1,"count":1,"detail":"百炼青锋，剑脊含光。"},
	{"name":"金创药","icon":"potion","type":2,"count":5,"detail":"外敷内服，行走江湖的常备药品。"},
	{"name":"碧竹草","icon":"herb","type":3,"count":12,"detail":"山涧采得，可用作药材。"},
	{"name":"干粮","icon":"food","type":2,"count":8,"detail":"赶路时补充体力。"},
	{"name":"武学残卷","icon":"scroll","type":3,"count":2,"detail":"残页记着几式运气法门。"}]
var item_grid:GridContainer
var details:Label
var use_button:Button
var chosen_item := 1
var skill_grid:GridContainer
var skill_filter:OptionButton
var hp_bar:ProgressBar
var mp_bar:ProgressBar
var dialogue:Label
var dialogue_page := 0
var next_button:Button
var previous_button:Button
var tasks:Array[CheckBox] = []
var volume:HSlider
var muted:CheckBox
var bus := 0
var original_db := 0.0
var original_mute := false
var map_view:Control
var gallery:AcceptDialog
var gallery_widgets:Array[Control] = []
var equipment:Control
var equipment_details:Control
var equipment_action:Button
var equipped := [true,true,true,true,true]
var shop_search:Control
var shop_list:VBoxContainer
var shop_rows:Array[Control] = []
var confirmation:Control
var gold := 1250
var shop_items:Array = []
var pending_trade:Dictionary = {}
var item_catalog:Array = []
const DIALOGUE = ["客官，北门外风雪正紧。若要上山，不妨先备些金创药与干粮。",
	"近来竹林里常有剑气掠过。那位白衣剑客只说：剑有锋，心须静。",
	"此去江湖，山水迢迢。愿你守得初心，也记得回这间客栈喝一盏热茶。"]

func _ready() -> void:
	theme = load("res://UI/wuxia_theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for edge in ["left","top","right","bottom"]:add_theme_constant_override("margin_"+edge,18)
	box = VBoxContainer.new();box.add_theme_constant_override("separation",18)
	if kind==0:
		var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;scroll.add_child(box)
	else:add_child(box)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://UI/catalog.json")).skills
	item_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://UI/catalog.json")).get("items",[])
	match kind:
		0:components()
		1:build_inventory()
		2:build_skills()
		3:build_dialogue()
		4:build_settings()
		5:build_map()
		6:build_equipment()
		7:build_shop()

func label(text:String,size_px:int=20,ink:bool=false) -> Label:
	var node := Label.new();node.text = text;node.add_theme_font_size_override("font_size",size_px)
	if ink:node.theme_type_variation = "InkLabel"
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func button(text:String,action:Callable) -> Button:
	var node := Button.new();node.set_script(load("res://UI/TooltipButton.gd"));node.text = text;node.custom_minimum_size = Vector2(150,50)
	node.pressed.connect(action);return node

func row(parent:Node=null) -> HBoxContainer:
	if parent==null:parent = box
	var node := HBoxContainer.new();node.add_theme_constant_override("separation",16);parent.add_child(node);return node

func paper(parent:Node=null) -> VBoxContainer:
	if parent==null:parent = box
	var panel := PanelContainer.new();panel.theme_type_variation = "PaperPanel";panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column);return column

func bar(parent:Node,value:float,mana:bool=false) -> ProgressBar:
	var node := ProgressBar.new();node.value = value;node.custom_minimum_size = Vector2(280,36);node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mana:node.theme_type_variation = "ManaBar"
	parent.add_child(node);return node

func icon_button(path:String,count:int=0) -> Button:
	var node := Button.new();node.set_script(load("res://UI/IconSlot.gd"));node.custom_minimum_size = Vector2(88,88)
	node.artwork = load(path);node.quantity = count;return node

func components() -> void:
	box.add_child(label("组件与状态",30));box.add_child(label("移入、按下或用 Tab 聚焦按钮，查看边框与文字反馈。",18))
	var buttons := row()
	buttons.add_child(button("普通按钮",func():status.text = "普通按钮已触发"))
	var hover := button("移入查看悬停",func():status.text = "悬停按钮已触发");buttons.add_child(hover)
	var pressed := button("已选中",func():status.text = "可再次取消选中");pressed.toggle_mode = true;pressed.button_pressed = true;buttons.add_child(pressed)
	var disabled := button("不可用",func():pass);disabled.disabled = true;buttons.add_child(disabled)
	var samples := row()
	for entry in [["窄面板",Vector2(230,128)],["宽面板",Vector2(540,210)]]:
		var panel := PanelContainer.new();panel.theme_type_variation = "PaperPanel";panel.custom_minimum_size = entry[1]
		panel.add_child(label(entry[0]+"\n边角保持原尺寸，文字独立显示。",20,true));samples.add_child(panel)
	var meters := paper()
	meters.add_child(label("生命与内力",26,true));hp_bar = bar(meters,72);mp_bar = bar(meters,46,true)
	var slider := HSlider.new();slider.min_value = 0;slider.max_value = 100;slider.value = 72;slider.custom_minimum_size.y = 34
	slider.value_changed.connect(func(value:float):hp_bar.value = value;mp_bar.value = 100-value);meters.add_child(slider)
	var checks := row()
	for entry in [["显示任务标记",true,false],["待领取奖励",false,false],["不可用状态",true,true]]:
		var check := CheckBox.new();check.text = entry[0];check.button_pressed = entry[1];check.disabled = entry[2];checks.add_child(check)
	status = label("按钮可用鼠标和键盘操作；长文字提示会自动换行。",18);box.add_child(status)
	hover.tooltip_text = "提示示例：保持现有武侠像素风，文字可替换，按钮可拉伸。"
	box.add_child(button("20类复用组件 · 打开图鉴",show_gallery))

func widget(name:String,values:Dictionary,parent:Node) -> Control:
	var node:Control = load("res://UI/prefabs/"+name+".tscn").instantiate();node.data = values;parent.add_child(node);return node

func show_gallery() -> void:
	if gallery!=null:gallery.popup_centered(Vector2i(1120,740));return
	gallery = AcceptDialog.new();gallery.title = "P1/P2 · 20类可复用组件";gallery.theme = theme;gallery.ok_button_text = "返回";add_child(gallery)
	var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size = Vector2(1000,600);gallery.add_child(scroll)
	var content := VBoxContainer.new();content.size_flags_horizontal = Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",18);scroll.add_child(content)
	var names := ["Slider","Dropdown","Tooltip","TabNavigation","Pagination","InventoryGrid","ItemDetails","DialogueBox","TaskEntry","MiniMapDisplay","WindowHeader","ScrollingList","SearchField","QuantitySelector","EquipmentSlots","ShopItemRow","ConfirmationModal","StatusEffectBar","ToastMessage","Hotbar"]
	for i in range(names.size()):
		content.add_child(label("%s · %s"%[["U06","U07","U08","U09","U10","U11","U12","U13","U14","U15","U16","U17","U18","U19","U21","U22","U23","U20","U24","U25"][i],names[i]],22))
		var values:Dictionary = {}
		if i==5:values = {"items":[{"name":"青锋剑","icon":"res://UI/icons/items/sword.png","count":1}],"selected":0}
		if i==11:values = {"items":range(1,21).map(func(n):return "可滚动条目 %02d"%n)}
		var component := widget(names[i],values,content);gallery_widgets.append(component)
		if i==18:
			var messages := row(content)
			for entry in [["拾取","拾取：铁矿 × 1","info"],["购买","购买成功：回气丹 × 2","success"],["错误","纹银不足，未扣款。","error"]]:
				var sample:Array = entry;messages.add_child(button(sample[0],func():component.show_message(sample[1],sample[2],3)))
	gallery.popup_centered(Vector2i(1120,740))

func item_spec(id:String) -> Dictionary:
	for item in item_catalog:
		if item.id==id:return item
	assert(false,"Missing P1 item "+id);return {}

func build_equipment() -> void:
	var header := widget("WindowHeader",{"title":"行走江湖 · 装备展示"},box)
	header.activated.connect(func(_action:String):navigate.emit(0))
	box.add_child(label("选择装备槽，可卸下或重新装备。只修改本页展示数据，不影响城镇人物。",18))
	var body := row();var slots_data:Array = []
	for entry in [["武器","I01_iron_sword"],["衣物","I02_cloth_tunic"],["头部","I02_straw_hat"],["鞋子","I02_cloth_shoes"],["饰物","I02_sachet"]]:
		var spec := item_spec(entry[1]);slots_data.append({"name":entry[0],"item":spec.name,"icon":spec.icon})
	equipment = widget("EquipmentSlots",{"slots":slots_data},body);equipment.custom_minimum_size.x = 360
	var info := paper(body);equipment_details = widget("ItemDetails",{},info)
	# Paper children use the ink palette, including dynamically configured detail rows.
	equipment_details.add_theme_color_override("font_color",Color("302a20"))
	equipment_action = button("卸下装备",func():equipped[equipment.selected] = not equipped[equipment.selected];refresh_equipment());info.add_child(equipment_action)
	equipment.changed.connect(func(_index:int):refresh_equipment())
	status = label("装备属性为示例数值，不代表新战斗系统。",18);box.add_child(status);refresh_equipment()

func refresh_equipment() -> void:
	var index:int = equipment.selected;var item:Dictionary = equipment.data.slots[index]
	for i in range(equipped.size()):equipment.buttons[i].artwork = load(equipment.data.slots[i].icon) if equipped[i] else null;equipment.buttons[i].queue_redraw()
	equipment_details.configure({"name":item.name+" · "+(item.item if equipped[index] else "空槽"),"description":"此页可演示选中、装备与卸下；真实属性与存档需由游戏传入。","attributes":{"状态":"已装备" if equipped[index] else "未装备","示例属性":"攻击 +18" if index==0 else "防护 +8"}})
	for line in equipment_details.find_children("*","Label",true,false):line.theme_type_variation = "InkLabel"
	equipment_action.text = "卸下装备" if equipped[index] else "重新装备"

func build_shop() -> void:
	box.add_child(label("江湖商铺 · 买卖展示",30));box.add_child(label("搜索、数量、确认与余额联动，仅使用本页展示库存。",18))
	shop_search = widget("SearchField",{},box);shop_search.changed.connect(refresh_shop)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y = 360;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	shop_list = VBoxContainer.new();shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL;shop_list.add_theme_constant_override("separation",14);scroll.add_child(shop_list)
	for entry in [["I01_iron_sword",180,4],["I02_cloth_tunic",100,5],["I03_qi_pills",35,20],["I06a_silver_ingot",80,3]]:
		var spec := item_spec(entry[0]);shop_items.append({"name":spec.name,"icon":spec.icon,"price":entry[1],"stock":entry[2],"owned":2})
	status = label("",20);box.add_child(status)
	confirmation = widget("ConfirmationModal",{},box);confirmation.buttons[0].hide()
	confirmation.activated.connect(func(action:String):
		if action=="confirm":apply_trade()
		else:pending_trade.clear())
	refresh_shop("")

func refresh_shop(query:String="") -> void:
	for child in shop_list.get_children():shop_list.remove_child(child);child.queue_free()
	shop_rows.clear()
	for i in range(shop_items.size()):
		var item:Dictionary = shop_items[i];var index := i
		if not query.strip_edges().is_empty() and not item.name.contains(query.strip_edges()):continue
		var entry := widget("ShopItemRow",item,shop_list);shop_rows.append(entry)
		entry.activated.connect(func(action:String):request_trade(index,action,int(entry.primary.spin.value)))
	if shop_rows.is_empty():shop_list.add_child(label("没有匹配的物品。清除搜索可查看全部商品。",20))
	status.text = "纹银 %d · 展示库存与余额，不保存到游戏"%gold

func request_trade(index:int,action:String,quantity:int) -> void:
	if index<0 or index>=shop_items.size() or quantity<1 or action not in ["buy","sell"]:return
	var item:Dictionary = shop_items[index]
	if (action=="buy" and (quantity>item.stock or quantity*item.price>gold)) or (action=="sell" and quantity>item.owned):
		status.text = "余额或可交易数量不足，未扣款。";return
	pending_trade = {"index":index,"action":action,"quantity":quantity}
	confirmation.dialog.title = "确认购买" if action=="buy" else "确认售出"
	confirmation.dialog.dialog_text = "%s × %d\n单价 %d；合计 %d 纹银。\n只修改展示数据，不影响真实背包。"%[item.name,quantity,item.price,quantity*item.price]
	confirmation.open_confirmation()

func apply_trade() -> void:
	if pending_trade.is_empty():return
	var item:Dictionary = shop_items[pending_trade.index];var quantity:int = pending_trade.quantity;var cost:int = quantity*item.price
	if pending_trade.action=="buy":
		if quantity>item.stock or cost>gold:pending_trade.clear();return
		gold -= cost;item.stock -= quantity;item.owned += quantity
	else:
		if quantity>item.owned:pending_trade.clear();return
		gold += cost;item.stock += quantity;item.owned -= quantity
	pending_trade.clear();refresh_shop(shop_search.primary.text)

func build_inventory() -> void:
	box.add_child(label("行囊 · 物品与数量",30))
	var filters := row()
	for i in range(4):
		var index := i
		filters.add_child(button(["全部","兵器","药品食物","材料典籍"][i],func():item_filter = index;refresh_inventory()))
	var body := row();item_grid = GridContainer.new();item_grid.columns = 6;item_grid.add_theme_constant_override("h_separation",12);item_grid.add_theme_constant_override("v_separation",12);body.add_child(item_grid)
	var info := paper(body);info.custom_minimum_size.x = 290
	details = label("",22,true);details.custom_minimum_size = Vector2(260,200);info.add_child(details)
	use_button = button("使用一份",use_item);info.add_child(use_button)
	var gold := row();var coin := TextureRect.new();coin.texture = load("res://UI/icons/items/coin.png");coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED;gold.add_child(coin)
	var amount := label("纹银 1250 · 展示数据",20);amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL;gold.add_child(amount)
	status = label("选择格子查看物品；筛选与使用会更新此页的展示数量。",18);box.add_child(status)
	refresh_inventory()

func refresh_inventory() -> void:
	for child in item_grid.get_children():item_grid.remove_child(child);child.queue_free()
	slots.clear()
	for i in range(inventory.size()):
		var item:Dictionary = inventory[i]
		if item.count<=0 or (item_filter>0 and item.type!=item_filter):continue
		var slot := icon_button("res://UI/icons/items/"+item.icon+".png",item.count);var index := i
		slot.selected = chosen_item==index;slot.tooltip_text = item.name+" × "+str(item.count)+"\n"+item.detail
		slot.pressed.connect(func():chosen_item = index;refresh_inventory());item_grid.add_child(slot);slots.append(slot)
	while item_grid.get_child_count()<18:
		var empty := icon_button("res://UI/icons/items/coin.png");empty.artwork = null;empty.disabled = true;item_grid.add_child(empty)
	var selected:Dictionary = inventory[chosen_item]
	details.text = selected.name+"\n\n"+selected.detail+"\n\n数量："+str(selected.count)
	use_button.disabled = selected.type!=2 or selected.count<=0

func use_item() -> void:
	var item:Dictionary = inventory[chosen_item]
	if item.type!=2 or item.count<=0:return
	item.count -= 1;status.text = "已使用一份"+item.name+"。此页仅演示物品交互，不改变城镇战斗数据。";refresh_inventory()

func build_skills() -> void:
	box.add_child(label("武学 · 七派与四大强敌",30))
	var filters := row();skill_filter = OptionButton.new();skill_filter.custom_minimum_size = Vector2(280,48)
	skill_filter.add_item("全部招式（33）")
	var owners:Array[String] = []
	for spec in catalog:
		if not owners.has(spec.owner):owners.append(spec.owner);skill_filter.add_item(spec.owner)
	filters.add_child(skill_filter)
	skill_filter.item_selected.connect(func(index:int):refresh_skills("" if index==0 else owners[index-1]))
	var reset := button("重置演示冷却",func():
		for slot in slots:slot.cooldown = 0;slot.disabled = false;slot.queue_redraw())
	filters.add_child(reset)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y = 430;box.add_child(scroll)
	skill_grid = GridContainer.new();skill_grid.columns = 7;skill_grid.add_theme_constant_override("h_separation",20);skill_grid.add_theme_constant_override("v_separation",14);scroll.add_child(skill_grid)
	status = label("点击图标演示冷却；此页不释放招式。城镇 U/I/O 实战，F8 可听完整音效。",18);box.add_child(status)
	refresh_skills("")

func refresh_skills(owner:String) -> void:
	for child in skill_grid.get_children():skill_grid.remove_child(child);child.queue_free()
	slots.clear()
	for spec in catalog:
		if not owner.is_empty() and owner!=spec.owner:continue
		var column := VBoxContainer.new();column.custom_minimum_size.x = 120;skill_grid.add_child(column)
		var slot := icon_button(spec.icon);slot.custom_minimum_size = Vector2(112,84)
		var info:String = "可在城镇施放" if spec.runtime_enabled else "Boss战斗待接入" if spec.kind=="boss" else "人物施法待 API"
		slot.tooltip_text = spec.owner+" · "+spec.name+"\n"+info+"\n点击仅演示界面冷却。"
		slot.pressed.connect(func():slot.start_cooldown(3.0);status.text = spec.owner+" · "+spec.name+" · 冷却显示示例 / "+info)
		column.add_child(slot);slots.append(slot)
		var title := label(spec.name,18);title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;title.custom_minimum_size.x = 120;column.add_child(title)

func build_dialogue() -> void:
	box.add_child(label("江湖事 · 对话与任务",30))
	var content := paper();content.add_child(label("客栈掌柜",28,true))
	dialogue = label("",24,true);dialogue.custom_minimum_size = Vector2(780,120);content.add_child(dialogue)
	var nav := row(content);previous_button = button("上一页",func():dialogue_page -= 1;refresh_dialogue());next_button = button("继续交谈",func():dialogue_page += 1;refresh_dialogue())
	nav.add_child(previous_button);nav.add_child(next_button)
	var quest := paper();quest.add_child(label("示例任务 · 行前准备",26,true))
	for text in ["拜访客栈掌柜","携带三份干粮","前往北城门"]:
		var check := CheckBox.new();check.text = text
		for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:check.add_theme_color_override(key,Color("302a20"))
		quest.add_child(check);tasks.append(check)
		check.toggled.connect(func(_value:bool):status.text = "准备进度：%d / 3"%tasks.filter(func(t):return t.button_pressed).size())
	status = label("任务勾选为展示交互；对话可逐页切换，不烘焙在图片里。",18);box.add_child(status);refresh_dialogue()

func refresh_dialogue() -> void:
	dialogue_page = clampi(dialogue_page,0,DIALOGUE.size()-1);dialogue.text = DIALOGUE[dialogue_page]
	previous_button.disabled = dialogue_page==0;next_button.disabled = dialogue_page==DIALOGUE.size()-1

func build_settings() -> void:
	box.add_child(label("听风 · 音效设置",30));box.add_child(label("这里控制当前程序的实际音效音量。",20))
	bus = AudioServer.get_bus_index("SkillSFX")
	if bus<0:bus = 0
	original_db = AudioServer.get_bus_volume_db(bus);original_mute = AudioServer.is_bus_mute(bus)
	var content := paper();content.add_child(label("音效音量",26,true))
	volume = HSlider.new();volume.min_value = 0;volume.max_value = 100;volume.value = db_to_linear(original_db)*100;volume.custom_minimum_size = Vector2(700,48);content.add_child(volume)
	muted = CheckBox.new();muted.text = "静音";muted.button_pressed = original_mute
	for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:muted.add_theme_color_override(key,Color("302a20"))
	content.add_child(muted)
	status = label("",20,true);content.add_child(status)
	volume.value_changed.connect(func(value:float):AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(value/100,.0001)));refresh_volume())
	muted.toggled.connect(func(value:bool):AudioServer.set_bus_mute(bus,value);refresh_volume())
	content.add_child(button("恢复进入前设置",func():volume.value = db_to_linear(original_db)*100;muted.button_pressed = original_mute))
	refresh_volume()

func refresh_volume() -> void:
	status.text = "当前：%d%% · %s"%[roundi(volume.value),"已静音" if muted.button_pressed else "音效开启"]

func build_map() -> void:
	box.add_child(label("山川 · 小地图组件",30))
	box.add_child(label("建筑标记来自现有城镇布局；点按方位按钮可移动展示标记。",18))
	var content := paper();map_view = Control.new();map_view.set_script(load("res://UI/MiniMap.gd"));map_view.custom_minimum_size = Vector2(760,420);content.add_child(map_view)
	var nav := row()
	for entry in [["北城门",Vector2(2048,304)],["城中",Vector2(2048,1536)],["客栈",Vector2(1184,1888)],["南城门",Vector2(2048,2864)]]:
		var at:Vector2 = entry[1];nav.add_child(button(entry[0],func():map_view.player_position = at;map_view.queue_redraw();status.text = "展示坐标：%d，%d"%[at.x,at.y]))
	status = label("简化位置图，仅展示小地图组件。",18);box.add_child(status)
