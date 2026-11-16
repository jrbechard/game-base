extends GutTest
## === Logic_Bus_Trigger.connect_trigger_value: a cue can take the event's first argument ===

## A stand-in for the bus, with events of different argument counts.
class FakeBus extends Object:
	signal none
	signal one(value: float)
	signal two(value: float, other: int)
	signal six(a: float, b: int, c: int, d: int, e: int, f: int)

var bus: FakeBus
var got := []

func before_each() -> void:
	bus = FakeBus.new()
	got.clear()

func after_each() -> void:
	bus.free()

func _take(value: Variant) -> void:
	got.append(value)

func test_the_first_argument_reaches_the_action() -> void:
	var handler := Logic_Bus_Trigger.connect_trigger_value(bus, &"one", _take)
	assert_true(handler.is_valid())
	bus.one.emit(0.25)
	assert_eq(got, [0.25])

func test_later_arguments_are_dropped() -> void:
	Logic_Bus_Trigger.connect_trigger_value(bus, &"two", _take)
	bus.two.emit(0.5, 9)
	assert_eq(got, [0.5])
	Logic_Bus_Trigger.connect_trigger_value(bus, &"six", _take)
	bus.six.emit(0.75, 1, 2, 3, 4, 5)
	assert_eq(got, [0.5, 0.75])

func test_an_event_without_arguments_cannot_carry_a_value() -> void:
	assert_false(Logic_Bus_Trigger.connect_trigger_value(bus, &"none", _take).is_valid())

func test_an_unknown_event_gives_an_invalid_handler() -> void:
	assert_false(Logic_Bus_Trigger.connect_trigger_value(bus, &"nope", _take).is_valid())

func test_two_cues_on_one_event_both_hear_it() -> void:
	var seen_a := []
	var seen_b := []
	Logic_Bus_Trigger.connect_trigger_value(bus, &"one", func(v) -> void: seen_a.append(v))
	Logic_Bus_Trigger.connect_trigger_value(bus, &"one", func(v) -> void: seen_b.append(v))
	bus.one.emit(1.0)
	assert_eq(seen_a, [1.0])
	assert_eq(seen_b, [1.0])

func test_a_disconnected_handler_hears_nothing() -> void:
	var handler := Logic_Bus_Trigger.connect_trigger_value(bus, &"one", _take)
	Logic_Bus_Trigger.disconnect_trigger(bus, &"one", handler)
	bus.one.emit(0.5)
	assert_eq(got, [])

func test_the_pitch_and_strength_mapping_is_a_straight_line_between_the_ends() -> void:
	var cue := Data_Audio_Cue.new()
	cue.value_pitch_min = 1.0
	cue.value_pitch_max = 3.0
	assert_almost_eq(Global_Manager_SFX.pitch_for_value(cue, 0.0), 1.0, 0.0001)
	assert_almost_eq(Global_Manager_SFX.pitch_for_value(cue, 0.5), 2.0, 0.0001)
	assert_almost_eq(Global_Manager_SFX.pitch_for_value(cue, 1.0), 3.0, 0.0001)
	assert_almost_eq(Global_Manager_SFX.pitch_for_value(cue, 5.0), 3.0, 0.0001, "clamped")
	var fx := Data_Rumble_Effect.new()
	fx.value_strength_min = 0.4
	assert_almost_eq(Global_Manager_Rumble.gain_for_value(fx, 0.0), 0.4, 0.0001)
	assert_almost_eq(Global_Manager_Rumble.gain_for_value(fx, 1.0), 1.0, 0.0001)
	assert_almost_eq(Global_Manager_Rumble.gain_for_value(fx, -2.0), 0.4, 0.0001, "clamped")
