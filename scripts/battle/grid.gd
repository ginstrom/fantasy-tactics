extends RefCounted

## Battlefield terrain (Stage 5 D2, docs/plans/2026-08-23-stage-5-strategic-
## roster-expansion/decision-ledger.md's "Terrain representation/
## distribution" row): Cover tiles are hand-authored per encounter, exactly
## like EXPEDITIONS' own hand-placed positions/compositions -- there is no
## procedural distribution algorithm here or anywhere else. Whoever builds
## this Grid (BattleController._ready(), BattleStateFactory.build()) is
## responsible for populating cover_tiles for the encounters that need it;
## Grid itself never invents cover. Guard bonuses are missile-only balance
## numbers read from GameConfig at the point of use (see BattleController's
## try_attack_selected_unit()) -- Grid only stores which tier a tile has.
const COVER_NONE := ""
const COVER_LOW := "low"
const COVER_HIGH := "high"

var width: int
var height: int
## Vector2i tile -> COVER_LOW/COVER_HIGH. A tile absent from this dictionary
## has no cover (get_cover() below returns COVER_NONE for it).
var cover_tiles: Dictionary = {}


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


## COVER_NONE/COVER_LOW/COVER_HIGH for `tile`, defaulting to COVER_NONE for
## any tile no caller ever authored cover on.
func get_cover(tile: Vector2i) -> String:
	return String(cover_tiles.get(tile, COVER_NONE))


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func get_adjacent(pos: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = [
		pos + Vector2i.UP,
		pos + Vector2i.DOWN,
		pos + Vector2i.LEFT,
		pos + Vector2i.RIGHT,
	]

	var adjacent: Array[Vector2i] = []
	for candidate in candidates:
		if is_in_bounds(candidate):
			adjacent.append(candidate)
	return adjacent


## Battle range uses four-directional grid distance, matching movement and
## adjacency everywhere else in this project.
func get_manhattan_distance(from_pos: Vector2i, to_pos: Vector2i) -> int:
	return abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y)


## Bresenham raycasting checks only intermediate tiles: a defender standing
## on the destination never blocks its own attack line.
func has_line_of_sight(start_tile: Vector2i, end_tile: Vector2i, blocking_tiles: Array[Vector2i] = []) -> bool:
	var x: int = start_tile.x
	var y: int = start_tile.y
	var end_x: int = end_tile.x
	var end_y: int = end_tile.y
	var delta_x: int = abs(end_x - x)
	var delta_y: int = abs(end_y - y)
	var step_x: int = 1 if x < end_x else -1
	var step_y: int = 1 if y < end_y else -1
	var error: int = delta_x - delta_y

	while x != end_x or y != end_y:
		var doubled_error: int = error * 2
		if doubled_error > -delta_y:
			error -= delta_y
			x += step_x
		if doubled_error < delta_x:
			error += delta_x
			y += step_y
		var tile := Vector2i(x, y)
		if tile != end_tile and blocking_tiles.has(tile):
			return false
	return true


## Battlefield visibility (Stage 5 D2's "Battlefield visibility" row): every
## tile with unobstructed 360-degree line of sight from at least one entry in
## `viewer_positions`, using the exact same has_line_of_sight() primitive
## already used for ranged targeting/spell range -- this is a second, purely
## additive query, never a replacement for it (has_line_of_sight() also
## serves range/targeting legality when a caller supplies blockers; weapon
## targeting intentionally supplies none). `blocking_tiles` follows
## has_line_of_sight()'s existing
## contract verbatim: a tile that is itself the line's destination never
## blocks its own line, so every viewer's own tile and every tile actually
## reachable by an unobstructed line register as visible. Returns a
## Dictionary used as a tile set (tile -> true), matching get_tile_distances()'
## own lookup-friendly shape rather than an Array callers would have to scan.
func get_visible_tiles(viewer_positions: Array[Vector2i], blocking_tiles: Array[Vector2i] = []) -> Dictionary:
	var visible := {}
	for viewer in viewer_positions:
		if not is_in_bounds(viewer):
			continue
		visible[viewer] = true
		for y in height:
			for x in width:
				var tile := Vector2i(x, y)
				if visible.has(tile):
					continue
				if has_line_of_sight(viewer, tile, blocking_tiles):
					visible[tile] = true
	return visible


func get_attackable_tiles(
	from_pos: Vector2i,
	min_range: int,
	max_range: int,
	blocking_tiles: Array[Vector2i] = []
) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	for y in height:
		for x in width:
			var tile := Vector2i(x, y)
			var distance: int = get_manhattan_distance(from_pos, tile)
			if distance < min_range or distance > max_range:
				continue
			if has_line_of_sight(from_pos, tile, blocking_tiles):
				attackable.append(tile)
	return attackable


func get_tiles_in_range(start: Vector2i, move_range: int, is_blocked: Callable) -> Array[Vector2i]:
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	var reachable: Array[Vector2i] = []

	for _step in move_range:
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for neighbor in get_adjacent(pos):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				if is_blocked.call(neighbor):
					continue
				reachable.append(neighbor)
				next_frontier.append(neighbor)
		frontier = next_frontier

	return reachable


func get_tile_distances(start: Vector2i, move_range: int, is_blocked: Callable) -> Dictionary:
	var distances := {start: 0}
	var frontier: Array[Vector2i] = [start]

	for step in move_range:
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for neighbor in get_adjacent(pos):
				if distances.has(neighbor):
					continue
				if is_blocked.call(neighbor):
					continue
				distances[neighbor] = step + 1
				next_frontier.append(neighbor)
		frontier = next_frontier

	distances.erase(start)
	return distances


## Deterministic BFS route from start to target, inclusive of both endpoints,
## or [] when target is unreachable within move_range. Mirrors
## get_tile_distances()'s own BFS shape (same get_adjacent() neighbor order,
## same is_blocked contract, same "first frontier to claim a tile wins" rule
## via predecessors.has()) so the two never disagree about which tiles are
## reachable -- but this one also retains predecessors, so callers that need
## the actual route (not just its cost), such as
## BattleController.try_move_selected_unit() deriving facing from the
## route's final edge, have one to walk. Neighbor order is get_adjacent()'s
## own UP/DOWN/LEFT/RIGHT, so a target reachable by multiple equally-short
## routes always resolves to the same one.
func get_shortest_path(start: Vector2i, target: Vector2i, move_range: int, is_blocked: Callable) -> Array[Vector2i]:
	if start == target:
		return [start]

	var predecessors := {}
	var frontier: Array[Vector2i] = [start]

	for _step in move_range:
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for neighbor in get_adjacent(pos):
				if neighbor == start or predecessors.has(neighbor):
					continue
				if is_blocked.call(neighbor):
					continue
				predecessors[neighbor] = pos
				next_frontier.append(neighbor)
		frontier = next_frontier
		if predecessors.has(target):
			break

	if not predecessors.has(target):
		return []

	var path: Array[Vector2i] = [target]
	var current := target
	while current != start:
		current = predecessors[current]
		path.append(current)
	path.reverse()
	return path


## Combat-only adjacency: true for any of the eight neighboring tiles,
## cardinal or diagonal. Movement/pathing must keep using get_adjacent()
## (four-directional only, see get_shortest_path()/get_tile_distances());
## this helper is for melee attack legality only (weapons whose maximum
## range is one -- see battle_controller.gd's diagonal-melee slice).
func is_attack_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var delta_x: int = abs(a.x - b.x)
	var delta_y: int = abs(a.y - b.y)
	return max(delta_x, delta_y) == 1
