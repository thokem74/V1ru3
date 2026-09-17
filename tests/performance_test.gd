## Standalone validation runner; invoke with Godot --script. No high-score changes are persisted.
extends SceneTree
var game: Node3D
var frame_times: Array[float] = []

## Schedule the test coroutine after SceneTree initialization so scene nodes can enter safely.
func _initialize() -> void:
	call_deferred("run")

## Measure rendered frame times after warmup during late-wave combat and a seam crossing.
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.persist_record = false
	game.start()
	for e in game.enemies:
		e.dispose()
	game.enemies.clear()
	game.waves.landscape = 3
	game.waves.wave = 4
	game.build_landscape()
	game.spawn_wave()
	Input.action_press("fire")
	for i in range(600):
		game.player.grace = 2
		game.player.position = Vector3(1010 + i * 0.12, 65, 512)
		game.player.velocity = Vector3.ZERO
		game.player.landed = false
		await process_frame
		if i > 120:
			frame_times.append(root.get_process_delta_time() * 1000)
	Input.action_release("fire")
	frame_times.sort()
	print("RENDER PERFORMANCE: median %.2fms / p95 %.2fms / FPS %d" % [frame_times[frame_times.size() / 2], frame_times[int(frame_times.size() * 0.95)], Engine.get_frames_per_second()])
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
