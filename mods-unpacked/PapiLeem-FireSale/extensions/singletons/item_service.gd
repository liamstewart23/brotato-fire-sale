# item_service.gd extension - applies the Fire Sale discount at the price layer.
#
# The discount applies to ITEMS/WEAPONS only (get_value); reroll cost is left at its
# normal price. The only free rerolls during a sale come from the sale's own pool,
# handled in the BaseShop extension.
#
# The discount multiplies the FINAL computed price (after all existing discount
# items like Entrepreneur / Spyglass), so it stacks multiplicatively and never
# goes below 1. Because prices are recomputed live every render, the discount
# appears and reverts simply by toggling FireSaleState.active - no stored values.
#
# Recycle/sell value must NOT be discounted: get_recycling_value internally calls
# get_value twice, so we wrap it with FireSaleState.suppress to skip the discount
# during that re-entrant computation.

extends "res://singletons/item_service.gd"

var _fss = null


func _get_fss():
	if _fss == null or not is_instance_valid(_fss):
		var loop = Engine.get_main_loop()
		if loop and loop is SceneTree:
			_fss = loop.root.get_node_or_null("FireSaleState")
	return _fss


func get_value(wave: int, base_value: int, player_index: int, affected_by_items_price_stat: bool, is_weapon: bool, item_id: int = Keys.empty_hash) -> int:
	var v = .get_value(wave, base_value, player_index, affected_by_items_price_stat, is_weapon, item_id)
	var fss = _get_fss()
	if fss != null and fss.is_active() and not fss.suppress and affected_by_items_price_stat:
		v = int(max(1, round(v * fss.get_discount_factor())))
	return v


func get_recycling_value(wave: int, from_value: int, player_index: int, is_weapon: bool = false, affected_by_items_price_stat: bool = true) -> int:
	var fss = _get_fss()
	var had_suppress = false
	if fss != null:
		had_suppress = fss.suppress
		fss.suppress = true
	var r = .get_recycling_value(wave, from_value, player_index, is_weapon, affected_by_items_price_stat)
	if fss != null:
		fss.suppress = had_suppress
	return r
