class_name ServerEconomy
extends RefCounted

signal money_changed(peer_id: int, old_amount: int, new_amount: int)

var _money: Dictionary = {}
var _loss_streaks: Dictionary = {
	Team.Id.ANGELS: 0,
	Team.Id.DEMONS: 0,
}


func init_player(peer_id: int) -> void:
	_money[peer_id] = Economy.STARTING_MONEY


func remove_player(peer_id: int) -> void:
	_money.erase(peer_id)


func get_money(peer_id: int) -> int:
	return _money.get(peer_id, 0)


func set_money(peer_id: int, amount: int) -> void:
	var old := get_money(peer_id)
	_money[peer_id] = Economy.clamp_money(amount)
	if old != _money[peer_id]:
		money_changed.emit(peer_id, old, _money[peer_id])


func add_money(peer_id: int, amount: int) -> void:
	set_money(peer_id, get_money(peer_id) + amount)


func award_round_win(winning_team: int, objective_completed: bool,
		team_players: Dictionary) -> void:
	var reward := Economy.REWARD_WIN_OBJECTIVE if objective_completed \
		else Economy.REWARD_WIN_ELIMINATION
	for peer_id in team_players:
		if team_players[peer_id] == winning_team:
			add_money(peer_id, reward)
	_loss_streaks[winning_team] = 0


func award_round_loss(losing_team: int, team_players: Dictionary) -> void:
	_loss_streaks[losing_team] = _loss_streaks.get(losing_team, 0) + 1
	var bonus := Economy.get_loss_bonus(_loss_streaks[losing_team])
	for peer_id in team_players:
		if team_players[peer_id] == losing_team:
			add_money(peer_id, bonus)


func award_kill(killer_id: int, weapon_idx: int) -> void:
	var reward := Economy.get_kill_reward(weapon_idx)
	add_money(killer_id, reward)


func award_catalyst_activate(team_players: Dictionary, attack_team: int) -> void:
	for peer_id in team_players:
		if team_players[peer_id] == attack_team:
			add_money(peer_id, Economy.CATALYST_ACTIVATE_BONUS)


func purchase(peer_id: int, price: int) -> bool:
	if not Economy.can_afford(get_money(peer_id), price):
		return false
	add_money(peer_id, -price)
	return true


func reset_economy() -> void:
	for peer_id in _money:
		set_money(peer_id, Economy.STARTING_MONEY)
	_loss_streaks[Team.Id.ANGELS] = 0
	_loss_streaks[Team.Id.DEMONS] = 0


func get_loss_streak(team: int) -> int:
	return _loss_streaks.get(team, 0)
