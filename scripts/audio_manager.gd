extends Node
# Autoload named "Sfx". All the sounds of the game live here.
#   Sfx.click()   -> UI click (hooked AUTOMATICALLY on every Button, nothing to add by hand)
#   Sfx.woosh()   -> racket swing that missed
#   Sfx.zap()     -> electric racket hit the mosquito
#   Sfx.bite()    -> mosquito bites the human
#   Sfx.play_music() / stop_music() / toggle_music()  -> very quiet background loop
#   Sfx.make_buzz_player() -> positional mosquito loop (louder when close to the listener)

signal music_changed(enabled: bool)

const P_CLICK := "res://assets/click_sound_effect.mp3"
const P_WOOSH := "res://assets/woosh_sound_effect.mp3"
const P_ZAP := "res://assets/zap_sound_effect.mp3"
const P_BITE := "res://assets/bite_sound_effect.wav"
const P_BUZZ := "res://assets/mosquito_loop.mp3"
const P_MUSIC := "res://assets/game_loop.mp3"

const MUSIC_DB := -24.0  # "very low" background music

var music_enabled: bool = true

var _click: AudioStream
var _woosh: AudioStream
var _zap: AudioStream
var _bite: AudioStream
var _buzz: AudioStream
var _music: AudioStream
var _music_player: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click = _load(P_CLICK, false)
	_woosh = _load(P_WOOSH, false)
	_zap = _load(P_ZAP, false)
	_bite = _load(P_BITE, false)
	_buzz = _load(P_BUZZ, true)
	_music = _load(P_MUSIC, true)

	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_DB
	_music_player.stream = _music
	add_child(_music_player)

	# Every Button that ever enters the game gets the click sound automatically.
	get_tree().node_added.connect(_on_node_added)


func _load(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Sound file missing: " + path)
		return null
	var s := load(path) as AudioStream
	if loop:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		if not b.pressed.is_connected(click):
			b.pressed.connect(click)


func _play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	# all busy: steal the first one
	_pool[0].stream = stream
	_pool[0].volume_db = volume_db
	_pool[0].pitch_scale = pitch
	_pool[0].play()


func click() -> void:
	_play(_click, -4.0)


func woosh() -> void:
	_play(_woosh, -2.0, randf_range(0.95, 1.08))


func zap() -> void:
	_play(_zap, 0.0)


func bite() -> void:
	_play(_bite, -2.0, randf_range(0.95, 1.1))


# ---------------- music ----------------

func play_music() -> void:
	if music_enabled and _music != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled:
		play_music()
	else:
		stop_music()
	music_changed.emit(enabled)


func toggle_music() -> void:
	set_music_enabled(not music_enabled)


# ---------------- mosquito buzz ----------------

# A positional player: the AudioListener2D of the local player decides the volume/pan,
# so the human can locate the mosquito by ear.
func make_buzz_player() -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = _buzz
	p.max_distance = 560.0
	p.attenuation = 1.2
	p.panning_strength = 1.0
	p.autoplay = false
	return p
