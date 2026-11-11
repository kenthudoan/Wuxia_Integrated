extends Node

signal cue_played(cue:String)
const BUS = "SkillSFX"
var catalog_path := "res://Audio/catalog.json"
var gain_db := -8.0
var skills:Dictionary = {}
var clips:Dictionary = {}
var streams:Dictionary = {}
var players:Array[AudioStreamPlayer] = []
var loop_player:AudioStreamPlayer
var selected:Dictionary = {}
var elapsed := 0.0
var release_index := 0
var active := false
var loop_active := false
var loop_gain := 0.0
var loop_started := false
var last_impact := -1000
var cursor := 0
var log:Array = []

func _ready() -> void:
	var content:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	assert(content.skills.size()==33 and content.clips.size()==105)
	clips = content.clips
	for spec in content.skills:skills[spec.id] = spec
	if AudioServer.get_bus_index(BUS)<0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS);AudioServer.set_bus_volume_db(index,-3)
		AudioServer.add_bus_effect(index,AudioEffectLimiter.new())
	for cue in clips:
		var stream:AudioStreamWAV = load(catalog_path.get_base_dir()+"/"+clips[cue].file)
		assert(stream!=null and stream.stereo and stream.mix_rate==44100,cue)
		if clips[cue].loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0;stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		streams[cue] = stream
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = BUS;add_child(player);players.append(player)
	loop_player = AudioStreamPlayer.new();loop_player.bus = BUS;add_child(loop_player)

func remember(cue:String) -> void:
	if log.size()>=128:log.pop_front()
	log.append({"cue":cue,"time":elapsed})
	cue_played.emit(cue)

func play_cue(cue:String,strength:float=1.0) -> void:
	assert(clips.has(cue))
	if clips[cue].loop:
		loop_player.stop();loop_player.stream = streams[cue]
		loop_gain = 0;loop_active = true;loop_player.volume_db = -70;loop_player.play()
	else:
		var player := players[cursor]
		for offset in range(players.size()):
			var index := (cursor+offset)%players.size()
			if not players[index].playing:player = players[index];cursor = index;break
		cursor = (cursor+1)%players.size()
		player.stop();player.stream = streams[cue]
		player.volume_db = gain_db+linear_to_db(clampf(strength,.5,1.35))
		player.pitch_scale = 1.0;player.play()
	remember(cue)

func begin(id:String) -> void:
	assert(skills.has(id),id)
	stop_all();selected = skills[id];elapsed = 0;release_index = 0;loop_started = false
	log.clear();active = true
	play_cue(selected.cues.cast)

func advance(time:float) -> void:
	if not active:return
	elapsed = time
	while release_index<selected.release_times.size() and elapsed>=float(selected.release_times[release_index]):
		play_cue(selected.cues.release,.95 if release_index==0 else 1.1)
		release_index += 1
	if selected.loop_start!=null and not loop_started and elapsed>=float(selected.loop_start):
		loop_started = true;play_cue(selected.cues.loop)

func impact(damage:int=20) -> void:
	if selected.is_empty() or not active:return
	var now := Time.get_ticks_msec()
	if now-last_impact<80:return
	last_impact = now
	play_cue(selected.cues.impact,clampf(.7+float(damage)/100,.75,1.25))

func finish() -> void:
	active = false;loop_active = false

func stop_all() -> void:
	active = false;loop_active = false;loop_started = false;loop_gain = 0;last_impact = -1000
	for player in players:player.stop()
	if is_instance_valid(loop_player):loop_player.stop()

func set_gain(value:float) -> void:
	var difference := value-gain_db
	gain_db = value
	for player in players:
		if player.playing:player.volume_db += difference

func _process(delta:float) -> void:
	loop_gain = move_toward(loop_gain,1.0 if loop_active else 0.0,delta/.1)
	if is_instance_valid(loop_player) and loop_player.playing:
		loop_player.volume_db = gain_db-4+linear_to_db(maxf(loop_gain,.0001))
		if loop_gain<=0 and not loop_active:loop_player.stop()

func _exit_tree() -> void:
	stop_all()
	for player in players:player.stream = null
	if is_instance_valid(loop_player):loop_player.stream = null
	streams.clear()
