class_name ServerMatch
extends RefCounted

enum State {
	WARMUP,
	FREEZE,
	LIVE,
	ROUND_OVER,
	HALFTIME,
	MATCH_OVER,
}

signal state_changed(old_state: int, new_state: int)
signal round_started(round_number: int)
signal round_ended(winner_team: int, reason: StringName)
signal halftime_started()
signal match_ended(winner_team: int)

var state: int = State.WARMUP
var round_number: int = 0
var score: Dictionary = {Team.Id.ANGELS: 0, Team.Id.DEMONS: 0}

var state_timer: float = 0.0
var round_timer: float = 0.0

var attack_team: int = Team.Id.DEMONS
var defense_team: int = Team.Id.ANGELS

var rounds_per_half: int = 12
var max_rounds: int = 24
var rounds_to_win: int = 13

var round_time: float = 115.0
var freeze_time: float = 5.0
var round_over_time: float = 5.0
var halftime_time: float = 15.0
var warmup_min_players: int = 2

var economy: ServerEconomy
var round_timer_paused: bool = false
var catalyst_activated: bool = false

var _team_players: Dictionary = {}
var _alive_count: Dictionary = {Team.Id.ANGELS: 0, Team.Id.DEMONS: 0}
var _round_winner: int = Team.Id.UNASSIGNED


func _init() -> void:
	economy = ServerEconomy.new()


func register_settings(config: MatchConfig) -> void:
	config.register("mp_roundtime", round_time, "Round time in seconds", &"competitive")
	config.register("mp_freezetime", freeze_time, "Freeze time in seconds", &"competitive")
	config.register("mp_round_over_time", round_over_time, "Round over celebration time", &"competitive")
	config.register("mp_halftime", halftime_time, "Halftime duration in seconds", &"competitive")
	config.register("mp_rounds_per_half", rounds_per_half, "Rounds per half", &"competitive")
	config.register("mp_warmup_min_players", warmup_min_players, "Min players to start match", &"competitive")


func apply_settings(config: MatchConfig) -> void:
	round_time = config.get_float("mp_roundtime")
	freeze_time = config.get_float("mp_freezetime")
	round_over_time = config.get_float("mp_round_over_time")
	halftime_time = config.get_float("mp_halftime")
	rounds_per_half = config.get_int("mp_rounds_per_half")
	warmup_min_players = config.get_int("mp_warmup_min_players")
	rounds_to_win = rounds_per_half + 1
	max_rounds = rounds_per_half * 2


func tick(delta: float, player_count: int) -> void:
	match state:
		State.WARMUP:
			_tick_warmup(player_count)
		State.FREEZE:
			_tick_freeze(delta)
		State.LIVE:
			_tick_live(delta)
		State.ROUND_OVER:
			_tick_round_over(delta)
		State.HALFTIME:
			_tick_halftime(delta)
		State.MATCH_OVER:
			pass


func set_team(peer_id: int, team: int) -> void:
	_team_players[peer_id] = team
	economy.init_player(peer_id)


func remove_player(peer_id: int) -> void:
	var team: int = _team_players.get(peer_id, Team.Id.UNASSIGNED)
	_team_players.erase(peer_id)
	economy.remove_player(peer_id)
	if state == State.LIVE and Team.is_playing_team(team):
		_alive_count[team] = maxi(0, _alive_count[team] - 1)
		_check_elimination()


func report_kill(killer_id: int, victim_id: int, weapon_idx: int) -> void:
	if state != State.LIVE:
		return
	economy.award_kill(killer_id, weapon_idx)
	var victim_team: int = _team_players.get(victim_id, Team.Id.UNASSIGNED)
	if Team.is_playing_team(victim_team):
		_alive_count[victim_team] = maxi(0, _alive_count[victim_team] - 1)
		_check_elimination()


func get_alive_count(team: int) -> int:
	return _alive_count.get(team, 0)


func get_team(peer_id: int) -> int:
	return _team_players.get(peer_id, Team.Id.UNASSIGNED)


func get_team_players() -> Dictionary:
	return _team_players


func get_state_name() -> String:
	match state:
		State.WARMUP: return "WARMUP"
		State.FREEZE: return "FREEZE"
		State.LIVE: return "LIVE"
		State.ROUND_OVER: return "ROUND_OVER"
		State.HALFTIME: return "HALFTIME"
		State.MATCH_OVER: return "MATCH_OVER"
		_: return "UNKNOWN"


func get_remaining_time() -> float:
	match state:
		State.LIVE: return round_timer
		State.FREEZE: return state_timer
		State.ROUND_OVER: return state_timer
		State.HALFTIME: return state_timer
		_: return 0.0


# --- State transitions ---

func _change_state(new_state: int) -> void:
	var old := state
	state = new_state
	state_changed.emit(old, new_state)


func _tick_warmup(player_count: int) -> void:
	if player_count >= warmup_min_players:
		_start_round()


func _tick_freeze(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.LIVE)
		round_timer = round_time


func _tick_live(delta: float) -> void:
	if not round_timer_paused:
		round_timer -= delta
		if round_timer <= 0.0:
			_end_round(defense_team, &"time_expired")


func _tick_round_over(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		if _check_match_over():
			return
		if round_number == rounds_per_half:
			_start_halftime()
		else:
			_start_round()


func _tick_halftime(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_start_round()


func _start_round() -> void:
	round_number += 1
	round_timer_paused = false
	catalyst_activated = false
	_change_state(State.FREEZE)
	state_timer = freeze_time
	_count_alive_players()
	round_started.emit(round_number)


func _end_round(winner: int, reason: StringName) -> void:
	_round_winner = winner
	score[winner] = score.get(winner, 0) + 1

	var loser := Team.get_opposing(winner)
	var objective_completed := reason == &"objective"
	economy.award_round_win(winner, objective_completed, _team_players)
	economy.award_round_loss(loser, _team_players)

	_change_state(State.ROUND_OVER)
	state_timer = round_over_time
	round_ended.emit(winner, reason)


func end_round_external(winner: int, reason: StringName) -> void:
	if state == State.LIVE:
		_end_round(winner, reason)


func _start_halftime() -> void:
	_swap_teams()
	economy.reset_economy()
	_change_state(State.HALFTIME)
	state_timer = halftime_time
	halftime_started.emit()


func _swap_teams() -> void:
	var old_attack := attack_team
	attack_team = defense_team
	defense_team = old_attack

	for peer_id in _team_players:
		var team: int = _team_players[peer_id]
		if team == Team.Id.ANGELS:
			_team_players[peer_id] = Team.Id.DEMONS
		elif team == Team.Id.DEMONS:
			_team_players[peer_id] = Team.Id.ANGELS


func _check_match_over() -> bool:
	for team in [Team.Id.ANGELS, Team.Id.DEMONS]:
		if score.get(team, 0) >= rounds_to_win:
			_change_state(State.MATCH_OVER)
			match_ended.emit(team)
			return true
	if round_number >= max_rounds:
		var angels_score: int = score.get(Team.Id.ANGELS, 0)
		var demons_score: int = score.get(Team.Id.DEMONS, 0)
		if angels_score != demons_score:
			var winner := Team.Id.ANGELS if angels_score > demons_score else Team.Id.DEMONS
			_change_state(State.MATCH_OVER)
			match_ended.emit(winner)
			return true
		# Tied at max rounds — for now, just end (overtime is future work)
		_change_state(State.MATCH_OVER)
		match_ended.emit(Team.Id.UNASSIGNED)
		return true
	return false


func _check_elimination() -> void:
	if state != State.LIVE:
		return
	var angels_alive: int = _alive_count.get(Team.Id.ANGELS, 0)
	var demons_alive: int = _alive_count.get(Team.Id.DEMONS, 0)

	if catalyst_activated:
		if _alive_count.get(defense_team, 0) <= 0 and _alive_count.get(attack_team, 0) > 0:
			_end_round(attack_team, &"elimination")
	else:
		if angels_alive <= 0 and demons_alive > 0:
			_end_round(Team.Id.DEMONS, &"elimination")
		elif demons_alive <= 0 and angels_alive > 0:
			_end_round(Team.Id.ANGELS, &"elimination")


func _count_alive_players() -> void:
	_alive_count[Team.Id.ANGELS] = 0
	_alive_count[Team.Id.DEMONS] = 0
	for peer_id in _team_players:
		var team: int = _team_players[peer_id]
		if Team.is_playing_team(team):
			_alive_count[team] = _alive_count.get(team, 0) + 1
