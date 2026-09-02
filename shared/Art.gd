extends Node
class_name Art
## Lookup for the generated art pack described by shared/art/manifest.json.
##
## Every load is GUARDED and cached: a missing file returns null rather than
## erroring, and callers skip drawing it. That is deliberate — the art arrives
## as a separate deliverable, and a half-delivered pack should degrade to the
## procedural `_draw()` look the games shipped with rather than crash or spray
## errors. It also means deleting a PNG is a data change, never a code change.
##
## Paths mirror the manifest exactly, so this file and the manifest stay in
## sync by construction: change one path in the manifest, change one here.

const ROOT := "res://shared/art/"

static var _cache: Dictionary = {}

## Cached, guarded load. Returns null when the file is not in the project.
static func tex(rel_path: String) -> Texture2D:
	if _cache.has(rel_path):
		return _cache[rel_path]
	var full := ROOT + rel_path
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	_cache[rel_path] = t
	return t

## A prop or background inside one game's folder, e.g. game("archery", "bow").
static func game(game_id: String, file: String) -> Texture2D:
	return tex("games/%s/%s.png" % [game_id, file])

## A per-player variant, e.g. char("sprint", "char", 2) -> games/sprint/char_p2.png.
static func char_for(game_id: String, file: String, player: int) -> Texture2D:
	return tex("games/%s/%s_p%d.png" % [game_id, file, player])

static func icon(name: String) -> Texture2D:
	return tex("icons/%s.png" % name)

static func thumb(game_id: String) -> Texture2D:
	return tex("thumbs/%s.png" % game_id)

static func shell(name: String) -> Texture2D:
	return tex("shell/%s.png" % name)
