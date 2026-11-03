class_name Economy
extends RefCounted

const STARTING_MONEY := 800
const MAX_MONEY := 16000

const REWARD_WIN_ELIMINATION := 3250
const REWARD_WIN_OBJECTIVE := 3500

const LOSS_BONUS_BASE := 1400
const LOSS_BONUS_INCREMENT := 500
const LOSS_BONUS_MAX := 3400

const CATALYST_ACTIVATE_BONUS := 800

enum WeaponCategory { RIFLE, SMG, SNIPER, PISTOL, KNIFE, GRENADE }

const KILL_REWARDS := {
	WeaponCategory.RIFLE: 300,
	WeaponCategory.SMG: 600,
	WeaponCategory.SNIPER: 100,
	WeaponCategory.PISTOL: 300,
	WeaponCategory.KNIFE: 1500,
	WeaponCategory.GRENADE: 300,
}

# Maps weapon_idx (from weapon_registry) to economy category
const WEAPON_CATEGORY := {
	0: WeaponCategory.KNIFE,
	1: WeaponCategory.PISTOL,
	2: WeaponCategory.RIFLE,
	3: WeaponCategory.RIFLE,
	4: WeaponCategory.SNIPER,
}


static func get_loss_bonus(consecutive_losses: int) -> int:
	if consecutive_losses <= 0:
		return 0
	return mini(
		LOSS_BONUS_BASE + (consecutive_losses - 1) * LOSS_BONUS_INCREMENT,
		LOSS_BONUS_MAX)


static func get_kill_reward(weapon_idx: int) -> int:
	var category: int = WEAPON_CATEGORY.get(weapon_idx, WeaponCategory.RIFLE)
	return KILL_REWARDS.get(category, 300)


static func can_afford(money: int, price: int) -> bool:
	return money >= price


static func clamp_money(amount: int) -> int:
	return clampi(amount, 0, MAX_MONEY)
