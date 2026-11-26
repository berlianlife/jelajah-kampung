extends Node
## Autoload "AudioManager". No background music (by design).
## Buses: Voice (NPC voice-over, later), Ambience, SFX — each with its own volume.
## SFX are synthesized at startup so the prototype ships without audio assets.

const RATE := 22050
const BUSES := ["Voice", "Ambience", "SFX"]

var sounds: Dictionary = {}
var sfx_players: Array = []
var amb_player: AudioStreamPlayer
var bird_timer := 4.0

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	sounds["blip"] = _synth([[620.0, 0.07]], "tri", 0.35)
	sounds["open"] = _synth([[440.0, 0.08], [660.0, 0.1]], "tri", 0.35)
	sounds["pick"] = _synth([[523.0, 0.1], [784.0, 0.16]], "square", 0.18)
	sounds["done"] = _synth([[523.0, 0.18], [659.0, 0.18], [784.0, 0.18], [1046.0, 0.3]], "tri", 0.4)
	sounds["step"] = _synth([[150.0, 0.05]], "sine", 0.25, 0.6)
	sounds["bird"] = _synth([[2400.0, 0.08], [0.0, 0.04], [2650.0, 0.07]], "sine", 0.22, 1.3)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	amb_player = AudioStreamPlayer.new()
	amb_player.bus = "Ambience"
	add_child(amb_player)

func play(name: String) -> void:
	if not sounds.has(name):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[name]
			p.play()
			return

func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))

func _process(delta: float) -> void:
	bird_timer -= delta
	if bird_timer <= 0.0:
		bird_timer = randf_range(4.0, 10.0)
		amb_player.stream = sounds["bird"]
		amb_player.pitch_scale = randf_range(0.85, 1.2)
		amb_player.play()

## notes: [[freq, seconds], ...] played in sequence; freq 0 = rest.
func _synth(notes: Array, wave: String, vol: float, slide := 1.0) -> AudioStreamWAV:
	var total := 0
	for n in notes:
		total += int(n[1] * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var off := 0
	for n in notes:
		var f0: float = n[0]
		var count := int(n[1] * RATE)
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var f := f0 * lerpf(1.0, slide, t)
			phase += f / RATE
			var x := 0.0
			if f0 > 0.0:
				var ph := fmod(phase, 1.0)
				match wave:
					"square": x = 1.0 if ph < 0.5 else -1.0
					"tri": x = 4.0 * absf(ph - 0.5) - 1.0
					_: x = sin(TAU * ph)
			var env := minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
			data.encode_s16(off, int(clampf(x * env * vol, -1.0, 1.0) * 32767.0))
			off += 2
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
