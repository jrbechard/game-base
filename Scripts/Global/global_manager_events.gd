extends Node
## === Event bus ===
## Every cross-system event is declared here first, with a one-line description.
## Managers never call each other; they emit and listen here.
##
## Two blocks: BASE events are reusable in any game (see tools/base_files.txt).
## GAME events belong to one game; a new game replaces that block with its own.

# Why: signals here are emitted from other scripts, so Godot cannot see the use.
@warning_ignore_start("unused_signal")

# ==========================================================================
# BASE EVENTS (reusable)
# ==========================================================================

# === Scenes ===
## A screen finished swapping into Screen_Host.
signal scene_changed(scene_id: StringName)
## The company splash has played (or was skipped) and is done. Main then opens the first screen.
signal splash_finished

# === Input ===
## The player switched between keyboard, gamepad and mouse (mode is Global_Manager_Input.DeviceMode).
signal device_mode_changed(mode: int)
## The last-used pad changed type (type is Logic_Input_Layout.GamepadType); used for button icons.
signal gamepad_type_changed(type: int)
## A menu action fired, with the A/B swap applied. Includes stick repeats. Menus listen to this.
signal ui_action_triggered(action: StringName)
## A menu action is now held or released; used for button press visuals.
signal ui_action_held_changed(action: StringName, held: bool)

# === Menus ===
## Menu focus actually moved to another control (silent at a list's edge). Audio listens.
signal menu_navigated
## A menu control was activated.
signal menu_confirmed
## A menu was cancelled (back).
signal menu_cancelled
## A slider or chooser was adjusted with Left/Right (silent at its limit).
signal menu_adjusted

# === Settings ===
## Intent: a screen asks for a setting to change. Only Global_Manager_Settings acts on it.
signal setting_change_requested(key: StringName, value: Variant)
## A setting changed, or was loaded at startup. Listeners apply the parts they own (rumble strength).
signal setting_changed(key: StringName, value: Variant)
## Intent: give a short sample buzz at the current rumble strength (the settings screen asks for it).
signal rumble_preview_requested

# === Save ===
## A State_ resource changed and should be autosaved (carries its save key).
signal state_changed(state_key: StringName)
## The save file was written.
signal save_completed
## A load finished; success is false when no usable file was found.
signal load_completed(success: bool)

# ==========================================================================
# GAME EVENTS (per game; the two below are a worked example)
# ==========================================================================

# === Progress (example: replace with the game's own events) ===
## Intent: something asks for an item to be given. Only Global_Manager_Progress acts on it.
signal item_grant_requested(item_id: StringName)
## Progress gave the player an item.
signal item_acquired(item_id: StringName)

func init() -> void:
	pass
