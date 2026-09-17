## Standalone validation runner; invoke with Godot --script. No high-score changes are persisted.
extends SceneTree
# Rendering regression harness. Run with a graphical driver, never headless.

## Schedule the test coroutine after SceneTree initialization so scene nodes can enter safely.
func _initialize() -> void:
	call_deferred("run")

## Wait for a completed rendered frame and save the viewport image to the requested PNG path.
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

## Capture title, flight, map, and pause screens with deterministic camera/world setups.
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.persist_record = false
	await create_timer(0.4).timeout
	game.set_physics_process(false)
	await capture("/tmp/vector-plague-title.png")
	game.start()
	game.player.position = Vector3(512, 42, 485)
	game.player.landed = false
	game.player.grace = 0
	game.camera.position = game.player.position + Vector3(0, 7, 15)
	game.camera.look_at(game.player.position + Vector3(0, 2, -12))
	game.terrain.deposit(Vector3(540, 0, 430), 7, 1)
	for i in range(32):
		game.renderer.update_view(game.player.position)
	game.scenery.update_view(game.player.position)
	game.hud.refresh_radar()
	game.hud.queue_redraw()
	await capture("/tmp/vector-plague-flight.png")
	game.hud.large_map = true
	game.hud.queue_redraw()
	await capture("/tmp/vector-plague-map.png")
	game.mode = "pause"
	game.hud.queue_redraw()
	await capture("/tmp/vector-plague-pause.png")
	print("Visual captures saved to /tmp/vector-plague-*.png")
	game.queue_free()
	await create_timer(0.15).timeout
	quit()
