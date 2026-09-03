extends MiniGame
class_name SplitGame
## Base for games where each player has their own private, mirrored half.
##
## The half is authored ONCE, in Field's PLAYER space — (0,0) at the player's own
## top-left as they read it, +y running outward from the seam toward their own
## screen edge — and drawn twice under Field.player_xform(). Player 2's copy
## comes out rotated by PI and therefore right-way-up to them.
##
## Subclasses implement _draw_half(player) and get:
##   * half_size / play_rect  — the local geometry, recomputed on every layout()
##   * touches already converted into PLAYER space by InputManager, because
##     input_space is PLAYER, so a subclass never sees a viewport coordinate
##   * the transform reset handled for them. An un-reset canvas transform leaks
##     into every later draw call in the frame, and the symptom (everything
##     drawn after it lands rotated) looks nothing like its cause.
##
## Nothing here knows about any particular sport.

## The player's own area, in PLAYER space: inset by the seam band on the inside
## and the safe/edge margin on the outside.
var play_rect := Rect2()
var half_size := Vector2.ZERO
## Scales art authored against a ~560px-wide half onto the real screen.
var art_scale := 1.0

func _init() -> void:
	view_mode = ViewMode.SPLIT
	input_space = InputManager.Space.PLAYER

func layout() -> void:
	half_size = Field.half_size()
	var inner := Field.SEAM_BAND * 0.5
	var outer := Field.SAFE_OUTER + Field.EDGE_MARGIN
	play_rect = Rect2(
		Field.EDGE_MARGIN, inner,
		half_size.x - Field.EDGE_MARGIN * 2.0,
		half_size.y - inner - outer,
	)
	art_scale = clampf(play_rect.size.x / 560.0, 0.6, 1.4)
	_on_layout()
	queue_redraw()

## Subclass hook: recompute anything derived from play_rect. Must be idempotent —
## it runs on every viewport resize, mid-match, with live pieces on screen.
func _on_layout() -> void:
	pass

## The transform currently in effect inside _draw_half. Subclasses pass it to
## the Juice art helpers, which compose with it rather than replacing it -- a
## helper that called draw_set_transform() directly would clobber this and draw
## the sprite in screen space, on the wrong half, right way up.
var base_xform := Transform2D.IDENTITY

func _draw() -> void:
	for player in [1, 2]:
		base_xform = Field.player_xform(player)
		draw_set_transform_matrix(base_xform)
		_draw_half(player)
	base_xform = Transform2D.IDENTITY
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Subclass hook: draw one player's half in PLAYER space. Called once per player,
## with that player's transform already applied.
func _draw_half(_player: int) -> void:
	pass

## Both halves share one ground colour, drawn per-half so a subclass can tint or
## texture a player's own side later without touching the shell.
func draw_ground(color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, half_size), color)

## The generated scene background for this game, cropped to fill the half, with
## the flat ground colour behind it as the fallback when the art is absent.
func draw_scene(game_id: String, fallback: Color) -> void:
	draw_ground(fallback)
	Juice.cover(self, base_xform, Art.game(game_id, "bg"), Rect2(Vector2.ZERO, half_size))

## Convenience wrappers so a subclass never has to remember to pass base_xform.
func sprite(
	texture: Texture2D, center: Vector2, height: float,
	flip_h: bool = false, rotation: float = 0.0, modulate: Color = Color.WHITE,
) -> void:
	Juice.sprite(self, base_xform, texture, center, height, flip_h, rotation, modulate)

func tile_h(texture: Texture2D, rect: Rect2, height: float) -> void:
	Juice.tile_h(self, base_xform, texture, rect, height)
