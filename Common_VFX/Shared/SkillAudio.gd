extends Node

const CUES = ["suodi_cast", "suodi_wind", "suodi_end", "wanjian_gather", "wanjian_launch",
    "zanghua_rain", "zanghua_scatter", "rulai_flash", "rulai_fall", "rulai_impact",
    "taiji_open", "taiji_aura", "taiji_absorb", "taiji_reflect", "moying_charge",
    "moying_release", "moying_impact", "sword_slash", "sword_wave", "sword_hit"]
const LOOPS = ["suodi_wind", "zanghua_rain", "taiji_aura", "moying_charge"]
const LEVELS = {"suodi_wind": -22.0, "wanjian_launch": -18.0, "zanghua_rain": -22.0,
    "rulai_impact": -5.0, "taiji_aura": -22.0, "moying_charge": -23.0, "sword_hit": -16.0}
const BUS = "SkillSFX"
const VOICES = 12
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}
var cooldowns: Dictionary = {}
var cursor := 0


func _ready() -> void:
    if AudioServer.get_bus_index(BUS) < 0:
        AudioServer.add_bus()
        var index := AudioServer.bus_count - 1
        AudioServer.set_bus_name(index, BUS)
        AudioServer.set_bus_volume_db(index, -3.0)
        AudioServer.add_bus_effect(index, AudioEffectLimiter.new())
    for cue in CUES:
        var stream := load("res://Shared/Audio/" + cue + ".wav") as AudioStreamWAV
        assert(stream != null, "Missing skill sound: " + cue)
        if cue in LOOPS:
            stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            stream.loop_begin = 0
            stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
        streams[cue] = stream
    for i in range(VOICES):
        var player := AudioStreamPlayer.new()
        player.bus = BUS
        add_child(player)
        players.append(player)
    for cue in LOOPS:
        var player := AudioStreamPlayer.new()
        player.bus = BUS
        player.stream = streams[cue]
        player.volume_db = LEVELS[cue]
        add_child(player)
        loops[cue] = player


func play(cue: String, pitch: float = 1.0) -> void:
    var now := Time.get_ticks_msec()
    # Simultaneous hits share a single impact sound instead of piling up on a volley.
    if cue == "sword_hit" and now < int(cooldowns.get(cue, 0)): return
    cooldowns[cue] = now + 70
    var player: AudioStreamPlayer = players[cursor]
    for offset in range(VOICES):
        var index := (cursor + offset) % VOICES
        if not players[index].playing:
            player = players[index]
            cursor = index
            break
    cursor = (cursor + 1) % VOICES
    player.stop()
    player.stream = streams[cue]
    player.pitch_scale = pitch
    player.volume_db = LEVELS.get(cue, -10.0)
    player.play()


func set_loop(cue: String, active: bool, strength: float = 1.0, pitch: float = 1.0) -> void:
    var player: AudioStreamPlayer = loops[cue]
    player.pitch_scale = pitch
    var target := float(LEVELS[cue]) + linear_to_db(maxf(strength, 0.001)) if active else -70.0
    player.volume_db = move_toward(player.volume_db, target, 100.0 * get_physics_process_delta_time())
    if active and not player.playing:
        player.volume_db = -60.0
        player.play()
    elif not active and player.volume_db <= -69.0:
        player.stop()


func stop_all() -> void:
    for player in players: player.stop()
    for player in loops.values(): player.stop()
    cooldowns.clear()

func _exit_tree() -> void:
    stop_all()
    for player in players:player.stream=null
    for player in loops.values():player.stream=null
    streams.clear()
