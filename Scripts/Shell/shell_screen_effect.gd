class_name Shell_Screen_Effect
extends CanvasLayer
## === The CRT look over the whole game ===
## One overlay on its own layer above the screens and overlays but below the transition, so
## every screen (overworld, puzzles, settings) gets it with no per-screen code. The strength is
## the `screen_effect` setting (0 = off, 1 = full); this node only listens to the bus, it never
## asks the settings manager. The look is Ever Blue's in-game CRT. Pogne's splash has its own
## stronger one, so the overlay can be held back until the splash is done.

@onready var _rect: ColorRect = $Effect_Rect

func init(current_strength: float) -> void:
	if not Global_Manager_Events.setting_changed.is_connected(_on_setting_changed):
		Global_Manager_Events.setting_changed.connect(_on_setting_changed)
	set_strength(current_strength)

func set_strength(value: float) -> void:
	_rect.material.set_shader_parameter("effect_intensity", clampf(value, 0.0, 1.0))
	# Why: at 0 the shader would still copy the whole screen every frame for nothing.
	_rect.visible = value > 0.0

## Stay hidden until `done` fires (the splash), then show at the saved strength.
func hold_until(done: Signal) -> void:
	var strength: float = _rect.material.get_shader_parameter("effect_intensity")
	_rect.visible = false
	done.connect(func() -> void: set_strength(strength), CONNECT_ONE_SHOT)

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"screen_effect":
		set_strength(float(value))
