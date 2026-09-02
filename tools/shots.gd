extends Node
## Renders every game straight to a PNG, bypassing the shell entirely.
##
## This exists because the browser harness reaches a game by tapping a Game Select
## card, and card indices shift as the list scrolls -- during the art pass it
## silently screenshotted the WRONG game for four of the six sports games, so their
## composition went unreviewed and three shipped unplayable. Addressing a game by
## registry id cannot drift.
##
## Needs a real (if virtual) display, so unlike the other harnesses it is not
## --headless:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://tools/Shots.tscn

const OUT_DIR := "/tmp/shots"
## Frames to simulate before capturing, so anything driven by _process is in a
## representative state rather than its first-frame pose.
const WARMUP_FRAMES := 90

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	for category in GameManager.get_categories():
		for id in category["games"]:
			await _shoot(id)
	print("shots: wrote to %s" % OUT_DIR)
	get_tree().quit()

func _shoot(id: String) -> void:
	var path: String = GameManager.GAME_REGISTRY[id]["scene"]
	if not ResourceLoader.exists(path):
		print("shots: %s MISSING (%s)" % [id, path])
		return
	var game = load(path).instantiate()
	add_child(game)
	if not game is MiniGame:
		print("shots: %s did not instantiate as MiniGame -- script failed to parse" % id)
		game.queue_free()
		return
	game.setup({})
	game.start_match()
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, id])
	print("shots: %s %s" % [id, image.get_size()])
	game.queue_free()
	await get_tree().process_frame
