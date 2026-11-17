class_name Component_Background_Job
extends Node
## === Run slow work on a thread, always showing the LATEST result ===
## For work that takes a while and is asked for again and again (an editor checking a puzzle
## after every stroke). Call `request(input)` as often as you like:
##   - it waits `debounce` seconds after the last request, so a burst of changes is one job
##   - the job runs on a thread, so the game never freezes
##   - only one job runs at a time; requests that arrive meanwhile wait and are merged
##   - when a job finishes, `finished` is emitted ONLY if no newer request was made since; an
##     out-of-date result is dropped, so a slow old answer can never overwrite a newer one
## `work` is called as `work.call(input)` on the thread. It must be pure: no nodes, no scene
## tree, no signals, only plain data in and out (Logic_ functions are exactly that).

## A result for the newest request is ready.
signal finished(result: Variant)
## The job went from idle to waiting or running (true) or back to idle (false).
signal busy_changed(busy: bool)

## Seconds to wait after the last request before starting.
@export var debounce := 0.4
## The function to run: `func(input) -> Variant`.
var work: Callable

var _revision := 0            # counts requests; a result is fresh only if its revision is the latest
var _running_revision := 0
var _pending: Variant = null
var _has_pending := false
var _wait := 0.0
var _thread: Thread
var _busy := false

func _ready() -> void:
	set_process(false)

## Ask for the work to run on `input`. Replaces any request still waiting.
func request(input: Variant) -> void:
	_revision += 1
	_pending = input
	_has_pending = true
	_wait = debounce
	_set_busy(true)
	set_process(true)

## Forget any waiting request and ignore a running job's result.
func cancel() -> void:
	_revision += 1
	_has_pending = false
	_pending = null
	_update_busy()

## True while a request is waiting or running.
func is_busy() -> bool:
	return _busy

func _process(delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		var result: Variant = _thread.wait_to_finish()
		_thread = null
		if _running_revision == _revision:
			finished.emit(result)  # the newest request: deliver it
		# else: stale, dropped
	if _thread == null and _has_pending:
		_wait -= delta
		if _wait <= 0.0:
			_running_revision = _revision
			var input: Variant = _pending
			_pending = null
			_has_pending = false
			_thread = Thread.new()
			_thread.start(work.bind(input))
	_update_busy()
	if not _busy:
		set_process(false)

func _update_busy() -> void:
	_set_busy(_has_pending or _thread != null)

func _set_busy(now: bool) -> void:
	if now != _busy:
		_busy = now
		busy_changed.emit(now)

func _exit_tree() -> void:
	# Why: a Thread must be finished before it is freed.
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
