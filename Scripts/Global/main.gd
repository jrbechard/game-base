extends Node
## === Main: almost empty. Starts the autoloads in a fixed order, then opens the shell. ===

@export var first_screen: PackedScene
@onready var _screen_host: Node = $Screen_Host

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
	Global_Manager_Scenes.change_screen(first_screen, &"shell_empty")
