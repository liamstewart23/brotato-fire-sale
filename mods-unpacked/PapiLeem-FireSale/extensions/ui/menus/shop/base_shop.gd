# base_shop.gd extension - rolls the Fire Sale trigger and drives shop-side state.
#
# Extends the shared shop base, so it covers BOTH the solo (Shop) and co-op
# (CoopShop) layouts. All per-player state uses the existing player_index arrays
# and the _get_*(player_index) accessors, so the sale applies to every panel.
#
# Lifecycle: ._ready() builds the whole shop (items, reroll buttons, save). We then
# roll the trigger AFTER that, so all containers/buttons already exist. The price
# discount itself lives in the ItemService extension; here we open the sale's own
# reroll pool, refresh displayed prices, and spawn the countdown overlay. On expiry
# the overlay calls _on_fire_sale_expired() to revert prices.
#
# Free rerolls during the sale come from FireSaleState.sale_rerolls (a separate pool)
# and are spent FIRST, so the player's own free rerolls (_free_rerolls, e.g. from
# Dangerous Bunny) are never consumed or revoked by the sale.

extends "res://ui/menus/shop/base_shop.gd"

const FireSaleOverlay = preload("res://mods-unpacked/PapiLeem-FireSale/scripts/fire_sale_overlay.gd")
const FireSaleFx = preload("res://mods-unpacked/PapiLeem-FireSale/scripts/fire_sale_fx.gd")

# Trigger sting: a celebratory fanfare layered with a coin "cha-ching".
const STING_FANFARE = preload("res://resources/sounds/level_up.wav")
const STING_COIN = preload("res://items/materials/alt_sounds/coin_bag_ring_gemstone_item_01.wav")

var _fire_sale_initialized := false
var _fire_sale_overlay = null
var _fire_sale_fx = null


func _get_fss():
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("FireSaleState")
	return null


func _ready() -> void:
	._ready()
	# Guard against any double-dispatch of _ready - only roll/grant once.
	if _fire_sale_initialized:
		return
	_fire_sale_initialized = true
	_init_fire_sale()


func _init_fire_sale() -> void:
	var fss = _get_fss()
	if fss == null:
		return

	var player_count: int = RunData.get_player_count()

	# Resumed mid-sale from a save: the discount flag, remaining time and sale reroll
	# pool are already restored, so just re-arm the visuals. Do NOT re-roll, re-grant,
	# or replay the one-time intro/sting (fresh = false).
	if fss.is_active():
		for pi in player_count:
			set_reroll_button_price(pi)
		_spawn_overlay(fss.remaining_seconds)
		_spawn_fx(fss.remaining_seconds, false)
		return

	# Trigger guards.
	if fss.chance_percent <= 0.0:
		return
	if RunData.current_wave < fss.min_wave:
		return
	if fss.last_fire_sale_wave == RunData.current_wave - 1:
		return  # never two shops in a row
	if not Utils.get_chance_success(fss.chance_percent / 100.0):
		return

	# Start the sale. start() seeds the sale's own reroll pool; we never touch
	# _free_rerolls, so the player's own free rerolls stay intact.
	fss.start(RunData.current_wave, fss.duration_seconds)
	for pi in player_count:
		_get_shop_items_container(pi).reload_shop_items()
		set_reroll_button_price(pi)

	if fss.sfx_enabled:
		_play_sting()
	_spawn_overlay(fss.duration_seconds)
	_spawn_fx(fss.duration_seconds, true)


func _play_sting() -> void:
	SoundManager.play(STING_FANFARE, 0, 0.05, true)
	SoundManager.play(STING_COIN, -2.0, 0.1, true)


func _spawn_fx(remaining: float, fresh: bool) -> void:
	var fss = _get_fss()
	var parent = get_node_or_null("Content")
	if parent == null:
		parent = self
	_fire_sale_fx = FireSaleFx.new()
	_fire_sale_fx.shop = self
	_fire_sale_fx.remaining = remaining
	_fire_sale_fx.fresh = fresh
	if fss != null:
		_fire_sale_fx.duration = fss.duration_seconds
		_fire_sale_fx.particles_enabled = fss.particles_enabled
		_fire_sale_fx.intro_enabled = fss.intro_flourish_enabled
	parent.add_child(_fire_sale_fx)


func _spawn_overlay(remaining: float) -> void:
	var fss = _get_fss()
	var parent = get_node_or_null("Content")
	if parent == null:
		parent = self
	_fire_sale_overlay = FireSaleOverlay.new()
	_fire_sale_overlay.shop = self
	if fss != null:
		_fire_sale_overlay.duration = fss.duration_seconds
		_fire_sale_overlay.discount_percent = fss.discount_percent
		_fire_sale_overlay.free_rerolls = fss.free_rerolls
	_fire_sale_overlay.remaining = remaining
	parent.add_child(_fire_sale_overlay)


# Called by the overlay when the countdown reaches 0. Any unused sale rerolls simply
# expire (they live only in the sale pool, never in _free_rerolls).
func _on_fire_sale_expired() -> void:
	var fss = _get_fss()
	if fss == null:
		return
	fss.end()

	# Revert all displayed prices and reroll costs to full.
	var player_count: int = RunData.get_player_count()
	for pi in player_count:
		var result: Array = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[pi], pi)
		_reroll_price[pi] = result[0]
		_reroll_discount[pi] = result[1]
		set_reroll_button_price(pi)
		var container = _get_shop_items_container(pi)
		container.reload_shop_items()
		container.update_buttons_color()

	if _fire_sale_fx != null and is_instance_valid(_fire_sale_fx):
		_fire_sale_fx.on_expired()


# End the sale when leaving the shop for the next wave, so its active state never
# leaks into the next shop. The pause -> quit-to-menu path does NOT go through here,
# so a saved sale still resumes correctly on "continue run".
func _on_GoButton_pressed(player_index: int) -> void:
	var fss = _get_fss()
	if fss != null and fss.is_active():
		fss.end()
	._on_GoButton_pressed(player_index)


# A sale free reroll is available for this player right now?
func _has_sale_reroll(player_index: int) -> bool:
	var fss = _get_fss()
	return fss != null and fss.is_active() and fss.sale_rerolls[player_index] > 0


# While a sale reroll is available, force the price to 0 and show "0 (X)" where X is
# the number of sale rerolls left. Otherwise fall back to the normal display.
func set_reroll_button_price(player_index: int) -> void:
	var sale_free: bool = _has_sale_reroll(player_index)
	if sale_free:
		_reroll_price[player_index] = 0
	.set_reroll_button_price(player_index)
	if sale_free:
		var fss = _get_fss()
		var btn = _get_reroll_button(player_index)
		if btn != null and btn.has_method("set_text"):
			var txt: String = (tr("REROLL") + " - 0 (" + str(fss.sale_rerolls[player_index]) + ")").to_upper()
			if RunData.is_coop_run:
				btn.set_text(txt)
			else:
				btn.set_text("      " + txt)


# Spend a sale reroll first, without charging gold or consuming the player's own free
# rerolls. We temporarily flag a "bonus" reroll so the vanilla handler takes its
# free-bonus branch (which neither decrements _free_rerolls nor counts a paid reroll),
# then restore state and decrement the sale pool only if a reroll actually happened.
func _on_RerollButton_pressed(player_index: int) -> void:
	if not _has_sale_reroll(player_index):
		._on_RerollButton_pressed(player_index)
		return

	var saved_bonus: bool = _has_bonus_free_reroll[player_index]
	_has_bonus_free_reroll[player_index] = true
	_reroll_price[player_index] = 0

	var reroll_count_before: int = _reroll_count[player_index]
	._on_RerollButton_pressed(player_index)
	var did_reroll: bool = _reroll_count[player_index] > reroll_count_before

	_has_bonus_free_reroll[player_index] = saved_bonus

	if did_reroll:
		var fss = _get_fss()
		if fss != null:
			fss.sale_rerolls[player_index] = int(max(0, fss.sale_rerolls[player_index] - 1))

	set_reroll_button_price(player_index)
