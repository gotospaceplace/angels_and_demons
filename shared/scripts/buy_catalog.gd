class_name BuyCatalog
extends RefCounted

enum Slot { MELEE, PISTOL, PRIMARY, ARMOR }
enum Side { BOTH, ATTACK, DEFENSE }

const ITEMS := [
	{
		"id": &"usp",
		"name": "USP",
		"price": 500,
		"slot": Slot.PISTOL,
		"side": Side.BOTH,
		"weapon_idx": 1,
		"category": &"pistols",
	},
	{
		"id": &"ak47",
		"name": "AK-47",
		"price": 2700,
		"slot": Slot.PRIMARY,
		"side": Side.ATTACK,
		"weapon_idx": 2,
		"category": &"rifles",
	},
	{
		"id": &"m4a1",
		"name": "M4A1",
		"price": 3100,
		"slot": Slot.PRIMARY,
		"side": Side.DEFENSE,
		"weapon_idx": 3,
		"category": &"rifles",
	},
	{
		"id": &"awp",
		"name": "AWP",
		"price": 4750,
		"slot": Slot.PRIMARY,
		"side": Side.BOTH,
		"weapon_idx": 4,
		"category": &"rifles",
	},
	{
		"id": &"vest",
		"name": "Kevlar Vest",
		"price": 650,
		"slot": Slot.ARMOR,
		"side": Side.BOTH,
		"weapon_idx": -1,
		"armor_value": 50,
		"category": &"equipment",
	},
	{
		"id": &"fullarmor",
		"name": "Kevlar + Helmet",
		"price": 1000,
		"slot": Slot.ARMOR,
		"side": Side.BOTH,
		"weapon_idx": -1,
		"armor_value": 100,
		"category": &"equipment",
	},
]

const CATEGORIES := [&"pistols", &"rifles", &"equipment"]
const CATEGORY_NAMES := {
	&"pistols": "PISTOLS",
	&"rifles": "RIFLES",
	&"equipment": "EQUIPMENT",
}


static func get_item(index: int) -> Dictionary:
	if index < 0 or index >= ITEMS.size():
		return {}
	return ITEMS[index]


static func get_item_by_id(item_id: StringName) -> Dictionary:
	for i in ITEMS.size():
		if ITEMS[i]["id"] == item_id:
			return ITEMS[i]
	return {}


static func get_index(item_id: StringName) -> int:
	for i in ITEMS.size():
		if ITEMS[i]["id"] == item_id:
			return i
	return -1


static func get_items_for_category(category: StringName) -> Array:
	var result: Array = []
	for i in ITEMS.size():
		if ITEMS[i]["category"] == category:
			result.append({"index": i, "data": ITEMS[i]})
	return result


static func can_buy(index: int, money: int, team: int, attack_team: int,
		current_weapon_idx: int, current_armor: int) -> Dictionary:
	var item := get_item(index)
	if item.is_empty():
		return {"ok": false, "reason": "Unknown item"}

	if not Economy.can_afford(money, item["price"]):
		return {"ok": false, "reason": "Insufficient funds"}

	var side: int = item["side"]
	if side == Side.ATTACK and team != attack_team:
		return {"ok": false, "reason": "Attack team only"}
	if side == Side.DEFENSE and team == attack_team:
		return {"ok": false, "reason": "Defense team only"}

	if item["slot"] == Slot.ARMOR:
		var armor_val: int = item.get("armor_value", 0)
		if current_armor >= armor_val:
			return {"ok": false, "reason": "Already have equal or better armor"}
	elif item["slot"] == Slot.PRIMARY or item["slot"] == Slot.PISTOL:
		if current_weapon_idx == item["weapon_idx"]:
			return {"ok": false, "reason": "Already own this weapon"}

	return {"ok": true, "reason": ""}


static func item_count() -> int:
	return ITEMS.size()
