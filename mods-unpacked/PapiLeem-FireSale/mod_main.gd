# mod_main.gd - FireSale mod entry point.
#
# Adds an occasional "Fire Sale" flash-sale state to the between-wave shop:
#   * everything 90% off (configurable)
#   * a few free rerolls
#   * a live countdown timer, after which prices snap back to normal
#
# Script extensions registered:
#   1. singletons/run_data.gd   - persists the sale across save/load
#   2. singletons/item_service.gd - applies the discount at the price layer
#   3. ui/menus/shop/base_shop.gd - rolls the trigger, grants rerolls, drives UI
#
# Shared runtime state lives on a single FireSaleState node parented to /root so
# both the ItemService singleton and the per-instance shop extension can reach it
# across scene changes.

extends Node

const MOD_DIR = "PapiLeem-FireSale"
const MOD_LOG = "PapiLeem-FireSale"

const FireSaleStateScript = preload("res://mods-unpacked/PapiLeem-FireSale/fire_sale_state.gd")

var mod_dir_path := ""
var ext_dir := ""


func _init():
	ModLoaderLog.info("Init", MOD_LOG)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	ext_dir = mod_dir_path.plus_file("extensions")

	ModLoaderMod.install_script_extension(ext_dir + "/singletons/run_data.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/singletons/item_service.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/ui/menus/shop/base_shop.gd")


func _ready():
	_add_translations()

	# Create the shared state node, push config into it, then parent it to /root.
	# Deferred add so we don't add a child while the tree is still busy.
	var state = FireSaleStateScript.new()
	state.name = FireSaleStateScript.NODE_NAME
	_load_config(state)
	get_tree().root.call_deferred("add_child", state)

	ModLoaderLog.info("Ready", MOD_LOG)


func _load_config(state) -> void:
	var config = ModLoaderConfig.get_current_config(MOD_DIR)
	if config and config.data:
		state.chance_percent = float(config.data.get("chance_percent", state.chance_percent))
		state.duration_seconds = float(config.data.get("duration_seconds", state.duration_seconds))
		state.discount_percent = int(config.data.get("discount_percent", state.discount_percent))
		state.free_rerolls = int(config.data.get("free_rerolls", state.free_rerolls))
		state.min_wave = int(config.data.get("min_wave", state.min_wave))
		state.sfx_enabled = bool(config.data.get("sfx_enabled", state.sfx_enabled))
		state.particles_enabled = bool(config.data.get("particles_enabled", state.particles_enabled))
		state.intro_flourish_enabled = bool(config.data.get("intro_flourish_enabled", state.intro_flourish_enabled))
		ModLoaderLog.info("Config loaded - chance: %s%%, %ss, %s%% off, %s free rerolls" % [
			state.chance_percent, state.duration_seconds, state.discount_percent, state.free_rerolls], MOD_LOG)


func _add_translations() -> void:
	# Three short banner phrases in the game's 13 languages.
	#   FIRE_SALE_TITLE - the banner title / intro slam ("FIRE SALE")
	#   FIRE_SALE_OFF   - the discount word, shown as "90% <OFF>"
	#   FIRE_SALE_OVER  - the end-of-sale stamp
	var translations = {
		"en": {
			"FIRE_SALE_TITLE": "FIRE SALE",
			"FIRE_SALE_OFF": "OFF",
			"FIRE_SALE_OVER": "SALE OVER!",
		},
		"fr": {
			"FIRE_SALE_TITLE": "VENTE FLASH",
			"FIRE_SALE_OFF": "DE RÉDUCTION",
			"FIRE_SALE_OVER": "VENTE TERMINÉE !",
		},
		"es": {
			"FIRE_SALE_TITLE": "VENTA FLASH",
			"FIRE_SALE_OFF": "DE DESCUENTO",
			"FIRE_SALE_OVER": "¡VENTA TERMINADA!",
		},
		"de": {
			"FIRE_SALE_TITLE": "BLITZVERKAUF",
			"FIRE_SALE_OFF": "RABATT",
			"FIRE_SALE_OVER": "VERKAUF VORBEI!",
		},
		"ru": {
			"FIRE_SALE_TITLE": "РАСПРОДАЖА",
			"FIRE_SALE_OFF": "СКИДКА",
			"FIRE_SALE_OVER": "РАСПРОДАЖА ОКОНЧЕНА!",
		},
		"pt": {
			"FIRE_SALE_TITLE": "LIQUIDAÇÃO",
			"FIRE_SALE_OFF": "DE DESCONTO",
			"FIRE_SALE_OVER": "PROMOÇÃO ENCERRADA!",
		},
		"pl": {
			"FIRE_SALE_TITLE": "WYPRZEDAŻ",
			"FIRE_SALE_OFF": "TANIEJ",
			"FIRE_SALE_OVER": "KONIEC WYPRZEDAŻY!",
		},
		"it": {
			"FIRE_SALE_TITLE": "SVENDITA",
			"FIRE_SALE_OFF": "DI SCONTO",
			"FIRE_SALE_OVER": "SVENDITA FINITA!",
		},
		"tr": {
			"FIRE_SALE_TITLE": "ŞOK FİYATLAR",
			"FIRE_SALE_OFF": "İNDİRİM",
			"FIRE_SALE_OVER": "İNDİRİM BİTTİ!",
		},
		"zh": {
			"FIRE_SALE_TITLE": "限时特卖",
			"FIRE_SALE_OFF": "折扣",
			"FIRE_SALE_OVER": "特卖结束！",
		},
		"zh_TW": {
			"FIRE_SALE_TITLE": "限時特賣",
			"FIRE_SALE_OFF": "折扣",
			"FIRE_SALE_OVER": "特賣結束！",
		},
		"ja": {
			"FIRE_SALE_TITLE": "タイムセール",
			"FIRE_SALE_OFF": "オフ",
			"FIRE_SALE_OVER": "セール終了！",
		},
		"ko": {
			"FIRE_SALE_TITLE": "타임세일",
			"FIRE_SALE_OFF": "할인",
			"FIRE_SALE_OVER": "세일 종료!",
		},
	}
	for locale in translations:
		var t = Translation.new()
		t.locale = locale
		for key in translations[locale]:
			t.add_message(key, translations[locale][key])
		TranslationServer.add_translation(t)
