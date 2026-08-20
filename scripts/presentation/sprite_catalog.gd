extends RefCounted
class_name SpriteCatalog

## Presentation-only texture lookup for placeholder sprites. Never derive
## action legality, saved state, simulation output, or RNG from a
## visual_key or from this catalog.

const _WORLD_PARTY := preload("res://assets/art/placeholders/microfantasy/world_party.png")
const _PLAYER_WARRIOR := preload("res://assets/art/placeholders/microfantasy/player_warrior.png")
const _PLAYER_SCOUT := preload("res://assets/art/placeholders/microfantasy/player_scout.png")
const _PLAYER_CLERIC := preload("res://assets/art/placeholders/microfantasy/player_cleric.png")
const _ENEMY_GOBLIN := preload("res://assets/art/placeholders/microfantasy/enemy_goblin.png")
const _ENEMY_KOBOLD := preload("res://assets/art/placeholders/microfantasy/enemy_kobold.png")
const _ENEMY_ORC := preload("res://assets/art/placeholders/microfantasy/enemy_orc.png")
const _ENEMY_HOBGOBLIN := preload("res://assets/art/placeholders/microfantasy/enemy_hobgoblin.png")
const _ENEMY_OGRE := preload("res://assets/art/placeholders/microfantasy/enemy_ogre.png")

const _GROUND_LIGHT := preload("res://assets/art/placeholders/kenney_tiny_dungeon/ground_light.png")
const _GROUND_DARK := preload("res://assets/art/placeholders/kenney_tiny_dungeon/ground_dark.png")

const _UNIT_TEXTURES := {
	"world_party": _WORLD_PARTY,
	"player_warrior": _PLAYER_WARRIOR,
	"player_scout": _PLAYER_SCOUT,
	"player_cleric": _PLAYER_CLERIC,
	"enemy_goblin": _ENEMY_GOBLIN,
	"enemy_kobold": _ENEMY_KOBOLD,
	"enemy_orc": _ENEMY_ORC,
	"enemy_hobgoblin": _ENEMY_HOBGOBLIN,
	"enemy_ogre": _ENEMY_OGRE,
}


static func get_unit_texture(visual_key: String) -> Texture2D:
	return _UNIT_TEXTURES.get(visual_key, _ENEMY_GOBLIN)


static func get_tile_texture(is_light: bool) -> Texture2D:
	return _GROUND_LIGHT if is_light else _GROUND_DARK
