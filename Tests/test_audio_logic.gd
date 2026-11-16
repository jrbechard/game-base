extends GutTest
## === Build step 4f-1 tests: Logic_Bus_Trigger and Logic_Audio_Buses ===

# === Logic_Bus_Trigger ===
func test_event_argument_counts() -> void:
	var bus := Global_Manager_Events
	assert_eq(Logic_Bus_Trigger.event_arg_count(bus, &"menu_confirmed"), 0)
	assert_eq(Logic_Bus_Trigger.event_arg_count(bus, &"scene_changed"), 1)
	assert_eq(Logic_Bus_Trigger.event_arg_count(bus, &"ui_action_held_changed"), 2)

func test_unknown_and_node_own_signals_are_not_bus_events() -> void:
	assert_eq(Logic_Bus_Trigger.event_arg_count(Global_Manager_Events, &"no_such_event"), -1)
	assert_eq(Logic_Bus_Trigger.event_arg_count(Global_Manager_Events, &"ready"), -1, "Node's own signal does not count")

func test_trigger_fires_for_events_with_zero_one_and_two_arguments() -> void:
	var count := {"n": 0}
	var action := func() -> void: count["n"] += 1
	var handlers := []
	for event in [&"menu_confirmed", &"scene_changed", &"ui_action_held_changed"]:
		var h := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, event, action)
		assert_true(h.is_valid(), "%s connected" % event)
		handlers.append([event, h])
	Global_Manager_Events.menu_confirmed.emit()
	Global_Manager_Events.scene_changed.emit(&"x")
	Global_Manager_Events.ui_action_held_changed.emit(&"ui_accept", true)
	assert_eq(count["n"], 3, "the action ran once per event")
	for pair in handlers:
		Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, pair[0], pair[1])

func test_two_triggers_on_the_same_event_both_fire() -> void:
	# The bug this guards: Godot sees two bound callables of one method as one connection.
	var count := {"a": 0, "b": 0}
	var ha := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, &"menu_confirmed", func() -> void: count["a"] += 1)
	var hb := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, &"menu_confirmed", func() -> void: count["b"] += 1)
	assert_true(ha.is_valid() and hb.is_valid())
	Global_Manager_Events.menu_confirmed.emit()
	assert_eq(count, {"a": 1, "b": 1})
	Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, &"menu_confirmed", ha)
	Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, &"menu_confirmed", hb)

func test_unknown_event_gives_an_invalid_handler() -> void:
	var h := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, &"no_such_event", func() -> void: pass)
	assert_false(h.is_valid())

func test_disconnect_stops_firing_and_is_safe_twice() -> void:
	var count := {"n": 0}
	var h := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, &"menu_cancelled", func() -> void: count["n"] += 1)
	Global_Manager_Events.menu_cancelled.emit()
	Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, &"menu_cancelled", h)
	Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, &"menu_cancelled", h)
	Global_Manager_Events.menu_cancelled.emit()
	assert_eq(count["n"], 1)

# === Logic_Audio_Buses ===
func test_ensure_buses_creates_each_bus_once_and_sends_to_master() -> void:
	Logic_Audio_Buses.ensure_buses()
	var count := AudioServer.bus_count
	Logic_Audio_Buses.ensure_buses()
	assert_eq(AudioServer.bus_count, count, "calling twice adds nothing")
	for bus_name in Logic_Audio_Buses.BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		assert_ne(index, -1, "%s exists" % bus_name)
		assert_eq(AudioServer.get_bus_send(index), Logic_Audio_Buses.MASTER, "%s sends to Master" % bus_name)

func test_volume_round_trips_by_name() -> void:
	Logic_Audio_Buses.ensure_buses()
	assert_true(Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 0.5))
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 0.5, 0.001)
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 1.0)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 1.0, 0.001)
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 7.0)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 1.0, 0.001, "clamped to 1")

func test_zero_volume_is_silent() -> void:
	Logic_Audio_Buses.ensure_buses()
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.UI, 0.0)
	assert_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Logic_Audio_Buses.UI)), Logic_Audio_Buses.SILENT_DB)
	assert_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.UI), 0.0)
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.UI, 1.0)

func test_unknown_bus_warns_and_reads_zero() -> void:
	assert_false(Logic_Audio_Buses.set_volume(&"No_Such_Bus", 0.5))
	assert_push_warning_count(1)
	assert_eq(Logic_Audio_Buses.get_volume(&"No_Such_Bus"), 0.0)

func test_volume_by_name_survives_a_changed_bus_order() -> void:
	Logic_Audio_Buses.ensure_buses()
	# Pogne's hard-coded numbers break here: a new bus pushes every other bus down one place.
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Test_Inserted")
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 0.25)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 0.25, 0.001)
	assert_eq(AudioServer.get_bus_volume_db(1), 0.0, "the inserted bus was not touched")
	AudioServer.remove_bus(1)
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 1.0)
