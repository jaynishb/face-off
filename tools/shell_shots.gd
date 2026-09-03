extends Node
## Renders every SHELL screen, every party game, and the pre-launch prompts to a
## PNG. The sibling of tools/shots.gd, which covers the 1v1 games.
##
## It exists because nothing rendered these before, and it showed: after the
## portrait migration Party Mode still laid itself out for a 720-tall landscape
## screen -- a 1128px-wide tile grid on a 720px phone, and every party game
## pinned to the top with the bottom half of the screen empty. All of it parsed,
## and all of it passed the geometry and playability harnesses, because neither
## of those looks at a pixel.
##
## Needs a real (if virtual) display, so unlike the other harnesses it is not
## --headless:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://tools/ShellShots.tscn

const OUT_DIR := "/tmp/shellshots"
const SCREENS := {
	"main_menu": "res://shell/main_menu/MainMenu.tscn",
	"game_select": "res://shell/game_select/GameSelect.tscn",
	"party_select": "res://shell/party_select/PartyGameSelect.tscn",
	"settings": "res://shell/settings/Settings.tscn",
}
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	for screen_name in SCREENS:
		var path: String = SCREENS[screen_name]
		if not ResourceLoader.exists(path):
			print("shellshots: %s MISSING" % screen_name); continue
		var scene = load(path).instantiate()
		add_child(scene)
		for i in range(60):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, screen_name])
		print("shellshots: %s" % screen_name)
		scene.queue_free()
		await get_tree().process_frame
	for id in PartyManager.get_roster():
		var path: String = PartyManager.PARTY_GAME_REGISTRY[id]["scene"]
		if not ResourceLoader.exists(path):
			print("shellshots: party %s MISSING" % id); continue
		var g = load(path).instantiate()
		add_child(g)
		if not g is PartyGame:
			print("shellshots: party %s did not instantiate as PartyGame" % id)
			g.queue_free(); continue
		g.setup({})
		g.start()
		for i in range(60):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/party_%s.png" % [OUT_DIR, id])
		print("shellshots: party %s" % id)
		g.queue_free()
		await get_tree().process_frame
	# The two pre-launch prompts, which are CanvasLayers rather than scenes.
	var dice := DiceCountPrompt.new()
	add_child(dice)
	dice.show_prompt(3)
	for i in range(45):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/prompt_dice.png" % OUT_DIR)
	print("shellshots: prompt_dice")
	dice.queue_free()
	await get_tree().process_frame

	var movie := MovieGuessSetupPrompt.new()
	add_child(movie)
	movie.show_prompt({})
	for i in range(45):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/prompt_movie.png" % OUT_DIR)
	print("shellshots: prompt_movie")
	movie.queue_free()
	await get_tree().process_frame

	PartyManager.pending_game_id = "spin_the_wheel"
	var host = load("res://shell/party_host/PartyHost.tscn").instantiate()
	add_child(host)
	for i in range(60):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/party_host.png" % OUT_DIR)
	print("shellshots: party_host")
	host.queue_free()
	await get_tree().process_frame

	get_tree().quit()
