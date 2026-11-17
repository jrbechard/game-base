@tool
class_name Tool_Generate_Placeholder_Sounds
extends EditorScript
## === Generate placeholder sounds (short test tones) ===
## A new game has no sound files yet, so this writes simple tones to Assets/Audio/ so the
## audio system can be heard working. They are PLACEHOLDERS: replace them with real sound
## design by overwriting the .wav files (the Data/Audio cue files point at the same paths).
## Run from the editor (File > Run), or call generate() from a script.

const RATE := 22050

func _run() -> void:
	generate()

static func generate() -> void:
	# Menu sounds (UI bus).
	_save(_tone(1400.0, 0.035, 0.25), "res://Assets/Audio/UI/menu_navigate.wav")
	_save(_cat([_tone(660.0, 0.06, 0.3), _tone(990.0, 0.09, 0.3)]), "res://Assets/Audio/UI/menu_confirm.wav")
	_save(_cat([_tone(660.0, 0.06, 0.3), _tone(440.0, 0.09, 0.3)]), "res://Assets/Audio/UI/menu_cancel.wav")
	_save(_tone(900.0, 0.03, 0.22), "res://Assets/Audio/UI/menu_adjust.wav")
	# A pause menu opening (a quick rise) and closing (the same, falling).
	_save(_cat([_tone(500.0, 0.05, 0.28), _tone(750.0, 0.08, 0.28)]), "res://Assets/Audio/UI/menu_open.wav")
	_save(_cat([_tone(750.0, 0.05, 0.28), _tone(500.0, 0.08, 0.28)]), "res://Assets/Audio/UI/menu_close.wav")
	# Game cues (SFX bus).
	_save(_cat([_tone(523.25, 0.07), _tone(659.25, 0.07), _tone(783.99, 0.07), _tone(1046.5, 0.2)]), "res://Assets/Audio/SFX/item_acquired.wav")
	# Music loop: a soft pad. Whole cycles of every frequency fit in 4 s, so it loops without a click.
	var seconds := 4.0
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	for i in pad.size():
		var t := float(i) / RATE
		var chord := sin(TAU * 220.0 * t) + sin(TAU * 330.0 * t) + sin(TAU * 440.0 * t) + 0.6 * sin(TAU * 550.0 * t)
		pad[i] = 0.1 * chord * (0.8 + 0.2 * sin(TAU * 0.5 * t))
	_save(pad, "res://Assets/Audio/Music/placeholder_loop.wav")

# A tone with a short attack and a smooth fade-out, so it never clicks.
static func _tone(freq: float, seconds: float, volume := 0.35, square := false) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var wave := sin(TAU * freq * t)
		if square:
			wave = signf(wave)
		var attack := minf(1.0, t / 0.004)
		var release := pow(1.0 - float(i) / n, 1.5)
		out[i] = wave * volume * attack * release
	return out

static func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out

static func _save(samples: PackedFloat32Array, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var err := wav.save_to_wav(path)
	if err != OK:
		push_error("Tool_Generate_Placeholder_Sounds: could not write %s (%d)" % [path, err])
