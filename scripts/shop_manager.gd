class_name ShopManager
extends RefCounted

var inventory
var progression
var generator
var config: Dictionary
var last_error := ""

func setup(inv, progress, item_generator, shop_config: Dictionary) -> void:
	inventory = inv
	progression = progress
	generator = item_generator
	config = shop_config

func buy(product_id: String, quantity: int) -> Dictionary:
	last_error = ""
	var products: Dictionary = config.get("products", {})
	if not products.has(product_id):
		last_error = "商品不存在。"
		return {}
	var maximum := int(config.get("rules", {}).get("max_quantity", 20))
	if quantity < 1 or quantity > maximum:
		last_error = "购买数量必须在1到%d之间。" % maximum
		return {}
	var product: Dictionary = products[product_id]
	if int(product.get("required_stage", 0)) > 0 and not progression.is_stage_complete(int(product.required_stage)):
		last_error = "商品尚未解锁：需要先通关主线第%d关。" % int(product.required_stage)
		return {}
	var total := int(product.get("price", 0)) * quantity
	if progression.gold < total:
		last_error = "金币不足：需要%d，当前%d。" % [total, progression.gold]
		return {}
	if product.get("type", "") == "equipment" and inventory.items.size() + quantity > inventory.capacity:
		last_error = "背包空间不足，需要%d个空位。" % quantity
		return {}
	var granted: Array = []
	match product.get("type", ""):
		"equipment":
			for _index in range(quantity):
				var item: Dictionary = generator.generate(int(product.get("level", 1)), "商店购买", product.get("quality", "green"), product.get("slot", ""), product.get("template_id", ""))
				if item.is_empty() or not inventory.add_item(item, false):
					last_error = "商品生成失败，交易未完成。"
					return {}
				granted.append(item)
			inventory.save_to_disk()
		"material":
			var material_id: String = product.get("material_id", "")
			progression.materials[material_id] = int(progression.materials.get(material_id, 0)) + int(product.get("amount", 1)) * quantity
		"skill_book":
			var skill_id: String = product.get("skill_id", "")
			progression.skill_books[skill_id] = progression.skill_book_count(skill_id) + int(product.get("amount", 1)) * quantity
			granted.append(skill_id)
		_:
			last_error = "商品类型无效。"
			return {}
	progression.gold -= total
	progression.record_transaction("商店购买", "%s ×%d" % [product.get("name", product_id), quantity], -total)
	progression.changed.emit()
	progression.save_to_disk()
	return {"product_id": product_id, "quantity": quantity, "gold": -total, "items": granted}

func sell(instance_id: String) -> Dictionary:
	last_error = ""
	var item = inventory.find_item(instance_id)
	if item == null:
		last_error = "背包中找不到该装备。"
		return {}
	if bool(item.get("locked", false)):
		last_error = "锁定装备不可出售，请先解除锁定。"
		return {}
	if is_equipped(instance_id):
		last_error = "穿戴中的装备不可出售，请先卸下。"
		return {}
	var value := sell_price(item)
	var index: int = inventory.items.find(item)
	if index < 0:
		last_error = "装备索引无效。"
		return {}
	inventory.items.remove_at(index)
	progression.gold += value
	progression.record_transaction("出售装备", item.get("name", instance_id), value)
	inventory.inventory_changed.emit()
	inventory.save_to_disk()
	progression.changed.emit()
	progression.save_to_disk()
	return {"instance_id": instance_id, "gold": value}

func sell_price(item: Dictionary) -> int:
	return maxi(5, int(item.get("level", 1)) * 4 + (int(item.get("quality_rank", 0)) + 1) * 10)

func is_equipped(instance_id: String) -> bool:
	for actor_id in inventory.equipped:
		if instance_id in inventory.equipped[actor_id].values():
			return true
	return false
