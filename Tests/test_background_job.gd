extends GutTest
## === Component_Background_Job: debounced thread work that never delivers a stale result ===

var job: Component_Background_Job
var results := []
var _mutex := Mutex.new()
var _calls := 0

func before_each() -> void:
	results.clear()
	_calls = 0
	job = Component_Background_Job.new()
	job.debounce = 0.05
	job.work = Callable(self, "_double")
	add_child_autofree(job)
	job.finished.connect(func(r: Variant) -> void: results.append(r))

# Runs on the thread: pure maths, plus a counter guarded by a mutex.
func _double(x: Variant) -> Variant:
	_mutex.lock()
	_calls += 1
	_mutex.unlock()
	return x * 2

func _slow(x: Variant) -> Variant:
	OS.delay_msec(300)
	return x * 10

func test_a_request_produces_a_result() -> void:
	job.request(21)
	await wait_for_signal(job.finished, 3.0)
	assert_eq(results, [42])

func test_nothing_runs_before_the_debounce_has_passed() -> void:
	job.debounce = 0.3
	job.request(1)
	await wait_seconds(0.1)
	assert_eq(_calls, 0)
	assert_true(job.is_busy())
	await wait_for_signal(job.finished, 3.0)
	assert_eq(results, [2])

func test_a_burst_of_requests_is_one_job_with_the_last_input() -> void:
	for i in 10:
		job.request(i)
	await wait_for_signal(job.finished, 3.0)
	await wait_seconds(0.2)
	assert_eq(results, [18], "only the last request's answer")
	assert_eq(_calls, 1, "and only one job ran")

func test_a_stale_result_is_dropped_when_a_newer_request_arrives_during_the_job() -> void:
	job.work = Callable(self, "_slow")
	job.request(1)
	await wait_seconds(0.15)          # the slow job is running now
	job.request(2)                    # a newer request: the running one is out of date
	await wait_for_signal(job.finished, 5.0)
	await wait_seconds(0.2)
	assert_eq(results, [20], "the old answer (10) never arrived, only the newer one")

func test_cancel_drops_a_waiting_request() -> void:
	job.debounce = 0.2
	job.request(5)
	job.cancel()
	await wait_seconds(0.5)
	assert_eq(results, [])
	assert_eq(_calls, 0)
	assert_false(job.is_busy())

func test_cancel_drops_a_running_jobs_result() -> void:
	job.work = Callable(self, "_slow")
	job.request(5)
	await wait_seconds(0.15)
	job.cancel()
	await wait_seconds(0.6)
	assert_eq(results, [])
	assert_false(job.is_busy())

func test_it_reports_when_it_is_busy_and_when_it_is_idle() -> void:
	var changes := []
	job.busy_changed.connect(func(b: bool) -> void: changes.append(b))
	job.request(1)
	await wait_for_signal(job.finished, 3.0)
	await wait_seconds(0.1)
	assert_eq(changes, [true, false])
	assert_false(job.is_busy())

func test_it_can_be_used_again_after_finishing() -> void:
	job.request(1)
	await wait_for_signal(job.finished, 3.0)
	job.request(2)
	await wait_for_signal(job.finished, 3.0)
	assert_eq(results, [2, 4])

func test_leaving_the_tree_while_a_job_runs_does_not_crash() -> void:
	job.work = Callable(self, "_slow")
	job.request(1)
	await wait_seconds(0.15)
	job.queue_free()
	await wait_seconds(0.5)
	assert_eq(results, [])
