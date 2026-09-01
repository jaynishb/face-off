extends RefCounted
class_name PromptDeck
## Loads a local JSON content file, filters by tag values, and draws a random
## entry while avoiding immediate repeats. Shared by any party game that
## reveals a random filtered thing from bundled content (Movie Guess,
## Category Blitz) rather than each game re-implementing JSON loading. Pure
## data helper -- instanced per-game via PromptDeck.new(), no autoload needed.

var _entries: Array = []
var _recent_keys: Array = []
const RECENT_LIMIT := 12 ## avoid repeating the last N reveals when the pool allows it

func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("PromptDeck: missing content file '%s'" % path)
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("PromptDeck: '%s' did not parse as a JSON array" % path)
		return false
	_entries = parsed
	return true

## Returns the sorted, deduplicated set of values present for a given field
## across all entries -- used to populate filter OptionButtons from real
## data instead of a hand-maintained duplicate list.
func distinct_values(field: String) -> Array:
	var seen := {}
	for entry in _entries:
		if entry.has(field):
			seen[entry[field]] = true
	var values := seen.keys()
	values.sort()
	return values

## filters: field_name -> value. A value of "" or "Any" (or an absent key)
## matches everything for that field.
func filtered(filters: Dictionary) -> Array:
	var result := []
	for entry in _entries:
		var match_all := true
		for field in filters:
			var want = filters[field]
			if want == "" or want == "Any":
				continue
			if entry.get(field) != want:
				match_all = false
				break
		if match_all:
			result.append(entry)
	return result

## Picks a random entry from the filtered pool, excluding recently-served
## entries when the pool is bigger than the recency window. Returns {} if the
## filtered pool is empty (caller must handle this -- e.g. "no matches, try
## different filters" instead of crashing on a random-index-into-empty-array).
func draw_random(filters: Dictionary = {}) -> Dictionary:
	var pool := filtered(filters)
	if pool.is_empty():
		return {}
	var candidates := pool
	if pool.size() > _recent_keys.size():
		candidates = pool.filter(func(e): return not _recent_keys.has(_key_for(e)))
	if candidates.is_empty():
		candidates = pool # pool smaller than/equal to recency window -- allow repeats
	var picked: Dictionary = candidates[randi() % candidates.size()]
	_remember(picked)
	return picked

func _key_for(entry: Dictionary) -> String:
	return str(entry) # entries are small flat dicts; stringifying is a cheap stable key

func _remember(entry: Dictionary) -> void:
	_recent_keys.append(_key_for(entry))
	if _recent_keys.size() > RECENT_LIMIT:
		_recent_keys.pop_front()

func reset_recent() -> void:
	_recent_keys.clear()
