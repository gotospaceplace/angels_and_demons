extends Node

signal command_received(command: String, args: String)

var _thread: Thread
var _mutex: Mutex
var _queue: Array[String] = []
var _running: bool = true


func _ready() -> void:
	_mutex = Mutex.new()
	_thread = Thread.new()
	_thread.start(_stdin_reader)
	print("[Console] Server console ready. Commands: status, kick <id>, say <message>, quit")


func _stdin_reader() -> void:
	while _running:
		var line := OS.read_string_from_stdin()
		line = line.strip_edges()
		if line.is_empty():
			continue
		_mutex.lock()
		_queue.append(line)
		_mutex.unlock()


func _physics_process(_delta: float) -> void:
	_mutex.lock()
	var commands := _queue.duplicate()
	_queue.clear()
	_mutex.unlock()

	for line in commands:
		_process_command(line)


func _process_command(line: String) -> void:
	var parts := line.split(" ", false, 1)
	var cmd := parts[0].to_lower()
	var args := parts[1] if parts.size() > 1 else ""
	command_received.emit(cmd, args)


func stop() -> void:
	_running = false
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
