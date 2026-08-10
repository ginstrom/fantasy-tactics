class_name SaveRepository
extends RefCounted
## Atomic-write / validated-read persistence for the single current-campaign
## save (see docs/plans/2026-08-10-initial-campaign-and-automation/
## 02-atomic-save-repository.md). A pure repository: it owns file paths,
## parse/compatibility errors, and atomic replacement only -- it never
## decides whether battle state is currently saveable (GameManager's
## boundary-guard job, see Step 3) and never touches scene/UI state.
##
## save_path is a constructor parameter (defaulting to the real user://
## location) specifically so tests can point a repository at a throwaway
## filename instead of ever writing the real save.

const DEFAULT_SAVE_PATH := "user://campaign-save.json"

## Distinct diagnostic codes for every way a load can fail, plus OK for
## success -- see load_campaign()/has_valid_save(). ABSENT and CORRUPT are
## about the file itself; WRONG_ENVELOPE means the JSON parsed but its
## top-level value is not an object at all; INVALID_SNAPSHOT means it is an
## object but CampaignSnapshot.from_dictionary() rejects its contents
## (unknown/missing version, malformed fields, dangling references, ...).
enum LoadStatus { OK, ABSENT, CORRUPT, WRONG_ENVELOPE, INVALID_SNAPSHOT }

var save_path: String


func _init(path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = path


## Exports `session`'s durable state (via export_campaign_snapshot()) and
## writes it atomically to save_path: the JSON text lands in a sibling
## temp file first (flushed and closed), which is only then renamed over
## save_path with DirAccess.rename_absolute(). The previous save is never
## opened for writing (let alone truncated) until the replacement has fully
## landed on disk, so a crash or power loss mid-write leaves either the old
## save intact or the fully-written new one -- never a half-written file at
## save_path. Returns {"ok": bool, "error": String}.
func save_campaign(session: Object) -> Dictionary:
	return _write(session.export_campaign_snapshot())


## Reads and validates save_path's envelope (exists, parses as JSON, is a
## JSON object), then -- only when that succeeds -- hands the normalized raw
## dictionary to `session.import_campaign_snapshot()`, which performs its
## own snapshot-level validation and, only on success, assigns session's
## fields (see GameSession.import_campaign_snapshot()'s all-or-nothing
## contract). Any failure at either stage (envelope or snapshot) returns
## before session is touched at all, so a failed load can never partially or
## fully overwrite a prepared session. Returns {"ok", "snapshot", "error",
## "status"}; "snapshot" is the typed, validated result on success (matching
## CampaignSnapshot.from_dictionary()'s own convention) and an empty
## Dictionary on any failure.
func load_campaign(session: Object) -> Dictionary:
	var envelope := _parse_and_normalize()
	if not envelope.ok:
		return envelope

	var import_result: Dictionary = session.import_campaign_snapshot(envelope.data)
	if not import_result.ok:
		return _load_failed(LoadStatus.INVALID_SNAPSHOT, import_result.error)
	return {"ok": true, "snapshot": import_result.snapshot, "error": "", "status": LoadStatus.OK}


## True only when save_path exists, parses as JSON, is a JSON object, and
## CampaignSnapshot.from_dictionary() accepts its contents -- i.e. exactly
## the cases load_campaign() would actually import. Uses
## CampaignSnapshot.from_dictionary() directly (rather than a session) since
## there is no session to import into here.
func has_valid_save() -> bool:
	var envelope := _parse_and_normalize()
	return envelope.ok and CampaignSnapshot.from_dictionary(envelope.data).ok


func _write(data: Dictionary) -> Dictionary:
	var tmp_path := "%s.tmp" % save_path
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _write_failed(
			"could not open %s for writing (error %d)" % [tmp_path, FileAccess.get_open_error()]
		)
	file.store_string(JSON.stringify(data))
	file.close()

	var rename_err := DirAccess.rename_absolute(tmp_path, save_path)
	if rename_err != OK:
		# The old save at save_path is untouched, but the half-finished
		# .tmp file would otherwise linger on disk indefinitely; a failed
		# removal here is not itself a reason to fail the write, whose own
		# error already reflects the real failure.
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return _write_failed(
			"could not replace %s with %s (error %d)" % [save_path, tmp_path, rename_err]
		)
	return {"ok": true, "error": ""}


func _write_failed(error: String) -> Dictionary:
	push_error("SaveRepository: %s" % error)
	return {"ok": false, "error": error}


## Envelope-only stage shared by load_campaign()/has_valid_save(): does
## save_path exist, parse as JSON, and hold a JSON object at its top level?
## Deliberately stops short of CampaignSnapshot.from_dictionary() -- callers
## decide how to finish validating (via a session's own
## import_campaign_snapshot(), or directly) since only load_campaign() has a
## session to hand normalized data to. On success, "data" is the same
## JSON-safe raw Dictionary shape session.export_campaign_snapshot()
## produces (tagged "version", Vector2i fields as {"x", "y"} dicts, ...),
## with every lossy JSON conversion already undone by
## _normalize_json_value().
func _parse_and_normalize() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _load_failed(LoadStatus.ABSENT, "%s does not exist" % save_path)

	# file_exists() passing does not guarantee open() succeeds -- permissions
	# or a deletion racing this read can still hand back null. Treat that the
	# same as ABSENT rather than crashing on get_as_text().
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _load_failed(
			LoadStatus.ABSENT,
			"%s could not be opened (error %d)" % [save_path, FileAccess.get_open_error()]
		)

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _load_failed(
			LoadStatus.CORRUPT,
			"%s is not valid JSON (%s at line %d)" % [save_path, json.get_error_message(), json.get_error_line()]
		)

	if typeof(json.data) != TYPE_DICTIONARY:
		return _load_failed(LoadStatus.WRONG_ENVELOPE, "%s does not contain a JSON object" % save_path)

	return {"ok": true, "data": _normalize_json_value(json.data), "error": "", "status": LoadStatus.OK}


func _load_failed(status: LoadStatus, error: String) -> Dictionary:
	return {"ok": false, "snapshot": {}, "error": error, "status": status}


## Undoes JSON's two lossy conversions for the Dictionary/Array structures
## CampaignSnapshot.to_dictionary() produces, so a real save/load round trip
## reproduces the exact typed structure that went in:
##
## - JSON has no int type -- Godot's JSON parser always hands back float for
##   every number, but CampaignSnapshot.from_dictionary() validates fields
##   like world_turn/gold strictly as `int`. Every whole-number float here
##   becomes an int. This is applied to the whole payload, including fields
##   CampaignSnapshot never touches directly (e.g. adventurers[].progression.
##   xp, a float by design -- see game_session.gd's default adventurer
##   template -- so fractional XP awards are never truncated on save). That
##   is intentionally safe here: a whole-number xp value round-trips back to
##   a float the moment it is next incremented (`+=` on an int promotes to
##   float) or compared (`>=` against a float threshold), and any fractional
##   xp value is never whole-number in the first place, so this normalizer
##   never touches it. Do not "fix" this into an XP-aware exclusion.
## - JSON object keys are always strings -- a Dictionary with int keys (e.g.
##   mana_crystals' tier -> count map) loses its key type entirely on the way
##   through JSON.stringify()/parse(). Every Dictionary key that is a valid
##   integer literal becomes an int key. This is safe everywhere in this save
##   format: every other id/key string a campaign snapshot carries
##   (adventurer/party/item/template ids, tutorial progress ids) always
##   contains a non-digit character, so it is left untouched.
static func _normalize_json_value(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value:
		return int(value)
	if value is Dictionary:
		var normalized_dict := {}
		for key in (value as Dictionary).keys():
			normalized_dict[_normalize_json_key(key)] = _normalize_json_value(value[key])
		return normalized_dict
	if value is Array:
		var normalized_array := []
		for item in value:
			normalized_array.append(_normalize_json_value(item))
		return normalized_array
	return value


static func _normalize_json_key(key: Variant) -> Variant:
	if key is String and key.is_valid_int():
		return int(key)
	return key
