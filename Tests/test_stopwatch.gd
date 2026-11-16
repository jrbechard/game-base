extends GutTest
## === Logic_Stopwatch: a stopwatch that counts up ===

func test_the_stopwatch_only_counts_while_running() -> void:
	var s := Logic_Stopwatch.new()
	s.update(5.0)
	assert_eq(s.elapsed, 0.0)
	s.start()
	s.update(1.5)
	s.update(2.0)
	assert_almost_eq(s.elapsed, 3.5, 0.0001)
	s.stop()
	s.update(10.0)
	assert_almost_eq(s.elapsed, 3.5, 0.0001)
	s.reset()
	assert_eq(s.elapsed, 0.0)

func test_a_restored_time_is_never_negative_or_broken() -> void:
	var s := Logic_Stopwatch.new()
	s.restore(-4.0)
	assert_eq(s.elapsed, 0.0)
	s.restore(NAN)
	assert_eq(s.elapsed, 0.0)
	s.restore(12.5)
	assert_almost_eq(s.elapsed, 12.5, 0.0001)

func test_time_is_shown_as_hours_minutes_seconds() -> void:
	assert_eq(Logic_Stopwatch.format(0.0), "00:00:00")
	assert_eq(Logic_Stopwatch.format(120.9), "00:02:00")
	assert_eq(Logic_Stopwatch.format(3725.0), "01:02:05")
	assert_eq(Logic_Stopwatch.format(-3.0), "00:00:00")
