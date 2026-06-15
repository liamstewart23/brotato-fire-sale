# fire_sale_overlay.gd - drives the Fire Sale countdown and its on-screen text.
#
# Instead of covering the store with a panel, this takes over the shop's title label
# ("Shop (Wave X)") and turns it into a live "FIRE SALE - 90% OFF - Ns" banner that
# pulses red in the final seconds, then restores the normal title when the sale ends.
# Co-op has no single title, so there we fall back to a slim banner at the top.
#
# The node is parented under the shop's "Content" so it inherits PAUSE_MODE_STOP (the
# countdown freezes under the pause menu) and is hidden along with the rest of the
# shop while paused. When the timer hits 0 we call shop._on_fire_sale_expired() to
# revert prices, flash "SALE OVER", then restore the title and free ourselves.

extends Control

# Injected by the BaseShop extension before add_child().
var shop = null
var duration := 30.0
var remaining := 30.0
var discount_percent := 90
var free_rerolls := 3

var _timer: Timer
var _title: Label = null          # solo: the shop title we take over
var _banner_label: Label = null   # co-op: our own slim banner
var _ended := false
var _pulse_t := 0.0
var _last_shown := -999
var _last_tick := -1

const COLOR_HOT := Color(1.0, 0.62, 0.12)
const COLOR_RED := Color(0.96, 0.18, 0.15)
const TICK_SOUND = preload("res://ui/sounds/clock_tick_01.wav")


func _ready() -> void:
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_title = _get_title_label()
	if _title == null:
		_build_coop_banner()

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = max(0.1, remaining)
	_timer.pause_mode = Node.PAUSE_MODE_INHERIT
	add_child(_timer)
	_timer.connect("timeout", self, "_on_timeout")
	_timer.start()


func _get_title_label():
	if shop == null:
		return null
	var t = shop.get_node_or_null("%Title")
	if t is Label:
		return t
	return null


func _build_coop_banner() -> void:
	_banner_label = Label.new()
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.align = Label.ALIGN_CENTER
	_banner_label.valign = Label.VALIGN_CENTER
	_banner_label.add_color_override("font_color", COLOR_HOT)
	_banner_label.add_color_override("font_color_shadow", Color(0, 0, 0))
	_banner_label.add_constant_override("shadow_offset_x", 2)
	_banner_label.add_constant_override("shadow_offset_y", 2)
	var f = _scaled_font(1.35)
	if f != null:
		_banner_label.add_font_override("font", f)
	_banner_label.anchor_left = 0.0
	_banner_label.anchor_right = 1.0
	_banner_label.anchor_top = 0.0
	_banner_label.anchor_bottom = 0.0
	_banner_label.margin_top = 6
	_banner_label.margin_bottom = 54
	add_child(_banner_label)


func _process(delta: float) -> void:
	if _ended or _timer == null:
		return

	var t: float = _timer.time_left
	remaining = t

	# Keep shared state's remaining time live so a mid-sale save captures it.
	var fss = _get_fss()
	if fss != null and fss.is_active():
		fss.remaining_seconds = t

	var col: Color = COLOR_HOT
	if t <= 5.0:
		_pulse_t += delta * 9.0
		var p: float = 0.5 + 0.5 * sin(_pulse_t)
		col = COLOR_HOT.linear_interpolate(COLOR_RED, p)

	var secs: int = int(ceil(t))

	# Tick once per second over the final 5 seconds.
	if t <= 5.0 and t > 0.05 and secs != _last_tick:
		_last_tick = secs
		if fss != null and fss.sfx_enabled:
			SoundManager.play(TICK_SOUND, 0, 0.05, true)

	if secs != _last_shown or t <= 5.0:
		_last_shown = secs
		var msg: String = tr("FIRE_SALE_TITLE") + "  -  " + str(discount_percent) + "% " + tr("FIRE_SALE_OFF") + "  -  " + str(secs) + "s"
		_apply(msg, col)


func _apply(msg: String, col: Color) -> void:
	if _title != null:
		_title.text = msg
		_title.modulate = col
	elif _banner_label != null:
		_banner_label.text = msg
		_banner_label.add_color_override("font_color", col)


func _on_timeout() -> void:
	if _ended:
		return
	_ended = true

	if shop != null and is_instance_valid(shop) and shop.has_method("_on_fire_sale_expired"):
		shop._on_fire_sale_expired()

	_apply(tr("FIRE_SALE_OVER"), COLOR_RED)

	# Linger on "SALE OVER", then restore the title and remove ourselves.
	yield(get_tree().create_timer(1.6), "timeout")
	if not is_instance_valid(self):
		return
	_restore_title()
	queue_free()


func _restore_title() -> void:
	if _title != null and is_instance_valid(_title):
		# Rebuild exactly what shop.gd sets, so the wave number stays correct.
		_title.text = tr("MENU_SHOP") + " (" + Text.text("WAVE", [str(RunData.current_wave)]) + ")"
		_title.modulate = Color(1, 1, 1, 1)


func _get_fss():
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("FireSaleState")
	return null


# Build an enlarged copy of the game's UI font for the co-op banner. Returns null
# (use default font) if the theme font isn't a DynamicFont.
func _scaled_font(factor: float):
	var src: Label = _find_label(shop)
	if src == null:
		return null
	var f = src.get_font("font")
	if f != null and f is DynamicFont:
		var nf: DynamicFont = f.duplicate()
		nf.size = int(max(8, f.size * factor))
		return nf
	return null


func _find_label(node: Node):
	if node == null:
		return null
	for child in node.get_children():
		if child is Label:
			return child
		var found = _find_label(child)
		if found != null:
			return found
	return null
