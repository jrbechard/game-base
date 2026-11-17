extends Node
## === Main: almost empty. Starts the autoloads in a fixed order, then opens the shell. ===

@export var first_screen: PackedScene
## Optional company splash shown before the first screen (empty = go straight to it).
@export var splash: PackedScene
@onready var _screen_host: Node = $Screen_Host
@onready var _screen_effect: Shell_Screen_Effect = $Screen_Effect

func _ready() -> void:
	# Why: explicit order instead of relying on autoload _ready order.
	Global_Manager_Events.init()
	Global_Manager_GameData.init()
	Global_Manager_Progress.init()
	Global_Manager_Save.init([Global_Manager_Progress.state])
	Global_Manager_Save.load_now()
	Global_Manager_Input.init()
	# Why: rumble asks the active input source for its pad; Main hands that in.
	Global_Manager_Rumble.init(func() -> int: return Global_Manager_Input.source.get_device())
	Global_Manager_SFX.init()
	Global_Manager_Music.init()
	Global_Manager_Settings.init()  # last of the audio and rumble managers, so it can apply to all of them
	Global_Manager_Scenes.init(_screen_host)
	_screen_effect.init(Global_Manager_Settings.get_value(&"screen_effect"))
	if splash == null:
		Global_Manager_Scenes.change_screen(first_screen, &"shell_empty")
		return
	# The company splash plays first and announces splash_finished; then the first screen opens.
	_screen_effect.hold_until(Global_Manager_Events.splash_finished)  # the splash has its own CRT
	Global_Manager_Events.splash_finished.connect(_on_splash_finished, CONNECT_ONE_SHOT)
	Global_Manager_Scenes.change_screen(splash, &"shell_splash")

func _on_splash_finished() -> void:
	Global_Manager_Scenes.change_screen(first_screen, &"shell_empty")
