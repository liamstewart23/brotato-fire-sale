# fire_sale_state.gd - shared runtime state for the Fire Sale.
#
# A single instance of this Node lives at /root/FireSaleState (added by mod_main).
# Both the ItemService extension (price discount) and the BaseShop extension
# (trigger / free rerolls / UI) read and mutate it, and RunData serialises it so a
# sale survives a mid-shop save/load.
#
# All live state is plain data so serialize()/deserialize() round-trips through the
# game's JSON save. Remaining time is stored as SECONDS LEFT (not a timestamp) so a
# reload resumes the countdown where it left off.

extends Node

const NODE_NAME = "FireSaleState"

# --- config (populated by mod_main from manifest.json) ---
var chance_percent := 8.0
var duration_seconds := 30.0
var discount_percent := 90
var free_rerolls := 3
var min_wave := 2

# FX toggles (let the player dial back the hype without code changes).
var sfx_enabled := true
var particles_enabled := true
var intro_flourish_enabled := true

# --- live state ---
var active := false
var remaining_seconds := 0.0
var started_wave := -1
var last_fire_sale_wave := -100
# The sale's OWN pool of free rerolls per player, separate from the player's normal
# free rerolls (_free_rerolls). Decremented as sale rerolls are spent; what's left
# when the timer ends simply expires. The player's own free rerolls are never touched.
var sale_rerolls := [0, 0, 0, 0]

# Re-entrancy guard: set true while computing recycle/sell value so the discount in
# the ItemService extension does NOT apply (sells must stay full price).
var suppress := false


func is_active() -> bool:
	return active


# Multiplier applied to a normal price to get the sale price (e.g. 0.1 for 90% off).
func get_discount_factor() -> float:
	return max(0.0, 1.0 - discount_percent / 100.0)


func start(wave: int, duration: float) -> void:
	active = true
	started_wave = wave
	last_fire_sale_wave = wave
	remaining_seconds = duration
	sale_rerolls = [free_rerolls, free_rerolls, free_rerolls, free_rerolls]


func end() -> void:
	active = false
	remaining_seconds = 0.0
	sale_rerolls = [0, 0, 0, 0]


func serialize() -> Dictionary:
	return {
		"active": active,
		"remaining_seconds": remaining_seconds,
		"started_wave": started_wave,
		"last_fire_sale_wave": last_fire_sale_wave,
		"sale_rerolls": sale_rerolls.duplicate(),
	}


func deserialize(d) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	active = bool(d.get("active", false))
	remaining_seconds = float(d.get("remaining_seconds", 0.0))
	started_wave = int(d.get("started_wave", -1))
	last_fire_sale_wave = int(d.get("last_fire_sale_wave", -100))
	var sr = d.get("sale_rerolls", [0, 0, 0, 0])
	if typeof(sr) == TYPE_ARRAY and sr.size() == 4:
		sale_rerolls = [int(sr[0]), int(sr[1]), int(sr[2]), int(sr[3])]
	else:
		sale_rerolls = [0, 0, 0, 0]
