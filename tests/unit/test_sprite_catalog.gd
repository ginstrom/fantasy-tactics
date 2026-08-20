extends GutTest


func test_world_party_texture_is_non_null() -> void:
	assert_not_null(SpriteCatalog.get_unit_texture("world_party"), "world_party must resolve to a texture")


func test_player_class_textures_are_non_null() -> void:
	for visual_key in ["player_warrior", "player_scout", "player_cleric"]:
		assert_not_null(SpriteCatalog.get_unit_texture(visual_key), "%s must resolve to a texture" % visual_key)


func test_enemy_family_textures_are_non_null() -> void:
	for visual_key in ["enemy_goblin", "enemy_kobold", "enemy_orc", "enemy_hobgoblin", "enemy_ogre"]:
		assert_not_null(SpriteCatalog.get_unit_texture(visual_key), "%s must resolve to a texture" % visual_key)


func test_unknown_unit_key_falls_back_to_a_non_null_texture() -> void:
	var fallback: Texture2D = SpriteCatalog.get_unit_texture("not_a_real_key")

	assert_not_null(fallback, "Unknown keys must still resolve to a texture")
	assert_eq(fallback, SpriteCatalog.get_unit_texture("enemy_goblin"), "Unknown keys fall back to enemy_goblin")


func test_all_nine_unit_keys_resolve_to_distinct_textures() -> void:
	# get_unit_texture() falls back to _ENEMY_GOBLIN for any unrecognized
	# key, and that fallback is itself non-null -- so a plain non-null check
	# per key (as the tests above do) would still pass even if every real
	# entry were deleted from _UNIT_TEXTURES; every key would just silently
	# resolve to the same fallback texture. Asserting all 9 real keys
	# resolve to 9 *distinct* Texture2D instances (Texture2D compares by
	# reference) catches missing keys, keys silently falling through to the
	# fallback, and any two keys accidentally mapped to the same file.
	var keys := [
		"world_party",
		"player_warrior",
		"player_scout",
		"player_cleric",
		"enemy_goblin",
		"enemy_kobold",
		"enemy_orc",
		"enemy_hobgoblin",
		"enemy_ogre",
	]
	var unique_textures := {}
	for visual_key in keys:
		var texture: Texture2D = SpriteCatalog.get_unit_texture(visual_key)
		unique_textures[texture] = true

	assert_eq(
		unique_textures.size(),
		9,
		"All 9 real unit keys must resolve to 9 distinct Texture2D instances"
	)


func test_tile_textures_are_non_null_and_distinct() -> void:
	var light: Texture2D = SpriteCatalog.get_tile_texture(true)
	var dark: Texture2D = SpriteCatalog.get_tile_texture(false)

	assert_not_null(light, "Light tile texture must be non-null")
	assert_not_null(dark, "Dark tile texture must be non-null")
	assert_ne(light, dark, "Light and dark tile textures must be distinct")
