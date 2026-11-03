class_name CompetitiveSpawns
extends RefCounted

var _angels_spawns: Array[Vector3] = []
var _demons_spawns: Array[Vector3] = []
var _swapped: bool = false
var _next_angel_idx: int = 0
var _next_demon_idx: int = 0


func load_spawns(angels_spawns: Array[Vector3], demons_spawns: Array[Vector3]) -> void:
	_angels_spawns = angels_spawns
	_demons_spawns = demons_spawns
	_next_angel_idx = 0
	_next_demon_idx = 0
	print("[Spawns] Loaded %d Angels spawns, %d Demons spawns" % [
		_angels_spawns.size(), _demons_spawns.size()])


func get_spawn_for_team(team: int) -> Vector3:
	var spawns := _get_team_spawns(team)
	if spawns.is_empty():
		return Vector3.ZERO
	var idx: int
	if team == _get_effective_team(Team.Id.ANGELS):
		idx = _next_angel_idx % spawns.size()
		_next_angel_idx += 1
	else:
		idx = _next_demon_idx % spawns.size()
		_next_demon_idx += 1
	return spawns[idx]


func reset_indices() -> void:
	_next_angel_idx = 0
	_next_demon_idx = 0


func swap_sides() -> void:
	_swapped = not _swapped
	reset_indices()
	print("[Spawns] Sides swapped (swapped=%s)" % _swapped)


func get_spawn_center(team: int) -> Vector3:
	var team_spawns := _get_team_spawns(team)
	if team_spawns.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for sp in team_spawns:
		sum += sp
	return sum / float(team_spawns.size())


func _get_team_spawns(team: int) -> Array[Vector3]:
	var effective := _get_effective_team(team)
	if effective == Team.Id.ANGELS:
		return _angels_spawns
	elif effective == Team.Id.DEMONS:
		return _demons_spawns
	return []


func _get_effective_team(team: int) -> int:
	if not _swapped:
		return team
	if team == Team.Id.ANGELS:
		return Team.Id.DEMONS
	elif team == Team.Id.DEMONS:
		return Team.Id.ANGELS
	return team
