extends Control

signal return_to_town
@export var town_mode := false
var sfx:Node
var specs:Array
var visible_ids:Array[String] = []
var picker:ItemList
var title:Label
var description:Label
var state:Label
var cue_name:Label
var timeline:ProgressBar
var wave:Control
var loop_button:Button
var selected := ""
var preview := false
var elapsed := 0.0
var impact_index := 0
var wave_clock := 0.0
var wave_seconds := 1.0
var wave_loop := false
var wave_running := false
var font:Font

func label(text:String,size_px:int) -> Label:
	var result := Label.new();result.text = text;result.add_theme_font_size_override("font_size",size_px);return result

func button(text:String,callback:Callable) -> Button:
	var result := Button.new();result.text = text;result.custom_minimum_size = Vector2(124,44);result.pressed.connect(callback);return result

func _ready() -> void:
	var scripts:String = get_script().resource_path.get_base_dir()
	var catalog_path := "res://assets/sect_skill_audio/catalog.json" if town_mode else "res://Audio/catalog.json"
	var background := ColorRect.new();background.color = Color("1b2e31");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	font = load("res://assets/fonts/SourceHanSansCN-Bold.otf" if town_mode else "res://fonts/SourceHanSansCN-Bold.otf")
	var theme_ui := Theme.new();theme_ui.default_font = font;theme_ui.default_font_size = 18;theme = theme_ui
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+edge,28)
	add_child(margin)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",15);margin.add_child(column)
	column.add_child(label("武林 · 技能音效试听",30))
	column.add_child(label("七派 21 招 / Boss 12 招  ·  施法、释放、命中与持续音"+("  ·  F2 返回城镇" if town_mode else ""),17))
	var body := HBoxContainer.new();body.size_flags_vertical = Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",26);column.add_child(body)
	var left := VBoxContainer.new();left.custom_minimum_size.x = 330;body.add_child(left)
	var filter := OptionButton.new();filter.add_item("全部技能（33）");left.add_child(filter)
	var content:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path));specs = content.skills
	var owners:Array[String] = []
	for spec in specs:
		if not owners.has(spec.owner):owners.append(spec.owner);filter.add_item(spec.owner)
	filter.item_selected.connect(func(index:int):populate("" if index==0 else owners[index-1]))
	picker = ItemList.new();picker.size_flags_vertical = Control.SIZE_EXPAND_FILL;picker.item_selected.connect(func(index:int):select(visible_ids[index]));left.add_child(picker)
	var right := VBoxContainer.new();right.size_flags_horizontal = Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",10);body.add_child(right)
	title = label("",32);right.add_child(title)
	description = label("",18);description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;right.add_child(description)
	wave = Control.new();wave.set_script(load(scripts+"/Waveform.gd"));wave.custom_minimum_size.y = 150;wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL;right.add_child(wave)
	cue_name = label("点击整招试听，或单独播放阶段音效",17);right.add_child(cue_name)
	var stages := HBoxContainer.new();stages.add_theme_constant_override("separation",8);right.add_child(stages)
	for entry in [["施法","cast"],["释放","release"],["命中 / 生效","impact"]]:stages.add_child(button(entry[0],play_stage.bind(entry[1])))
	loop_button = button("持续循环",play_stage.bind("loop"));stages.add_child(loop_button)
	var controls := HBoxContainer.new();controls.add_theme_constant_override("separation",8);right.add_child(controls)
	controls.add_child(button("整招试听  Space",play_skill));controls.add_child(button("停止  Esc",stop))
	controls.add_child(button("上一招",step.bind(-1)));controls.add_child(button("下一招",step.bind(1)))
	timeline = ProgressBar.new();timeline.show_percentage = false;timeline.custom_minimum_size.y = 12;right.add_child(timeline)
	state = label("未播放",17);right.add_child(state)
	var volume := HBoxContainer.new();right.add_child(volume)
	var volume_text := label("音量 -8 dB",17);volume.add_child(volume_text)
	var slider := HSlider.new();slider.min_value = -30;slider.max_value = 0;slider.value = -8;slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL;volume.add_child(slider)
	slider.value_changed.connect(func(value:float):sfx.set_gain(value);volume_text.text = "音量 %d dB"%value)
	var note := label("试听中的命中时刻为编排示例；城镇里按实际接触播放。\n缺施法动作的技能仍停用，Boss 尚未接入战斗。",15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;right.add_child(note)
	sfx = Node.new();sfx.set_script(load("res://SectSkillAudio.gd" if town_mode else scripts+"/SectSkillAudio.gd"));sfx.catalog_path = catalog_path;add_child(sfx);sfx.cue_played.connect(on_cue)
	populate("")

func populate(owner:String) -> void:
	picker.clear();visible_ids.clear()
	for spec in specs:
		if owner.is_empty() or owner==spec.owner:visible_ids.append(spec.id);picker.add_item(spec.owner+" · "+spec.name)
	if not visible_ids.is_empty():picker.select(0);select(visible_ids[0])

func select(id:String) -> void:
	stop();selected = id
	var index := visible_ids.find(id)
	if index>=0 and not picker.is_selected(index):picker.select(index);picker.ensure_current_is_visible()
	var spec:Dictionary = sfx.skills[id]
	title.text = spec.name;description.text = spec.owner+" · "+spec.sound_design
	loop_button.disabled = not spec.cues.has("loop")
	on_cue(spec.cues.cast);wave_clock = 0;wave.progress = 0;wave_running = false
	state.text = "未播放 · 选择阶段或整招试听"

func on_cue(cue:String) -> void:
	var data:Dictionary = sfx.clips[cue]
	wave.peaks = data.waveform;wave_seconds = data.seconds;wave_loop = data.loop;wave_clock = 0;wave_running = true
	cue_name.text = {"cast":"施法","release":"释放","impact":"命中 / 生效","loop":"持续循环"}[data.stage]+" · %.2f 秒"%data.seconds
	wave.queue_redraw()

func play_skill() -> void:
	preview = true;elapsed = 0;impact_index = 0;sfx.begin(selected)

func play_stage(stage:String) -> void:
	stop();sfx.play_cue(sfx.skills[selected].cues[stage]);state.text = "阶段试听 · Esc 停止"

func stop() -> void:
	preview = false;wave_running = false
	if is_instance_valid(sfx):sfx.stop_all()
	if is_instance_valid(state):state.text = "已停止"

func step(direction:int) -> void:
	var index := posmod(visible_ids.find(selected)+direction,visible_ids.size());picker.select(index);picker.ensure_current_is_visible();select(visible_ids[index])

func _input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if town_mode and event.keycode==KEY_F2:
		stop();get_viewport().set_input_as_handled();return_to_town.emit()
	elif event.keycode==KEY_SPACE:play_skill();get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:stop();get_viewport().set_input_as_handled()

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_LEFT:step(-1)
	elif event.keycode==KEY_RIGHT:step(1)

func _process(delta:float) -> void:
	if wave_running:wave_clock += delta
	if not wave_loop and wave_clock>=wave_seconds:wave_running = false
	if is_instance_valid(wave):wave.progress = fmod(wave_clock,wave_seconds)/wave_seconds if wave_loop else minf(1,wave_clock/wave_seconds);wave.queue_redraw()
	if not preview:return
	elapsed += delta
	var spec:Dictionary = sfx.skills[selected]
	sfx.advance(elapsed)
	while impact_index<spec.preview_impact_times.size() and elapsed>=float(spec.preview_impact_times[impact_index]):sfx.impact(32);impact_index += 1
	if elapsed>=float(spec.effect_seconds):sfx.finish()
	timeline.value = 100*elapsed/float(spec.audition_seconds)
	state.text = "整招试听 · %.2f / %.2f 秒"%[elapsed,spec.audition_seconds]
	if elapsed>=float(spec.audition_seconds):preview = false;state.text = "试听结束"
