class_name Team
extends RefCounted

enum Id {
	UNASSIGNED = 0,
	ANGELS = 1,
	DEMONS = 2,
	SPECTATOR = 3,
}

const COLOR_ANGELS := Color(0.3, 0.5, 1.0)
const COLOR_DEMONS := Color(1.0, 0.3, 0.3)
const COLOR_SPECTATOR := Color(0.7, 0.7, 0.7)

const PLAYER_COLORS := [
	Color(0.37, 0.55, 0.83),  # Blue
	Color(0.42, 0.78, 0.29),  # Green
	Color(0.83, 0.76, 0.37),  # Yellow
	Color(0.83, 0.55, 0.37),  # Orange
	Color(0.69, 0.37, 0.83),  # Purple
]


static func get_player_color(index: int) -> Color:
	if index < 0 or index >= PLAYER_COLORS.size():
		return Color.WHITE
	return PLAYER_COLORS[index]

const NAME_ANGELS := "Angels"
const NAME_DEMONS := "Demons"
const NAME_SPECTATOR := "Spectator"


static func get_team_name(team: int) -> String:
	match team:
		Id.ANGELS: return NAME_ANGELS
		Id.DEMONS: return NAME_DEMONS
		Id.SPECTATOR: return NAME_SPECTATOR
		_: return "Unassigned"


static func get_color(team: int) -> Color:
	match team:
		Id.ANGELS: return COLOR_ANGELS
		Id.DEMONS: return COLOR_DEMONS
		Id.SPECTATOR: return COLOR_SPECTATOR
		_: return Color.WHITE


static func get_opposing(team: int) -> int:
	match team:
		Id.ANGELS: return Id.DEMONS
		Id.DEMONS: return Id.ANGELS
		_: return Id.UNASSIGNED


static func is_playing_team(team: int) -> bool:
	return team == Id.ANGELS or team == Id.DEMONS


static func get_faction(team: int) -> String:
	match team:
		Id.DEMONS: return "demons"
		_: return "angels"
