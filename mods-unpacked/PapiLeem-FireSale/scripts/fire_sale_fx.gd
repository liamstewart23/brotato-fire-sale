# fire_sale_fx.gd - the "make it feel like an event" visual layer.
#
# Owns everything except the title banner/countdown (that's fire_sale_overlay.gd):
#   * a pulsing red/orange background tint behind the items (persistent),
#   * a one-time intro flourish (screen flash + slam-in "FIRE SALE!" + shop shake),
#   * periodic gold coin-burst particles on the shop's 2D effects layer.
#
# Spawned by the BaseShop extension and parented under "Content", so it freezes and
# hides with the pause menu and is freed when the shop scene changes. The one-time
# flourish only plays when `fresh` is true (a brand-new trigger), never on a save
# resume. on_expired() (called by the BaseShop extension) winds everything down.

extends Control

# Injected by the BaseShop extension before add_child().
var shop = null
var duration := 30.0
var remaining := 30.0
var fresh := true
var particles_enabled := true
var intro_enabled := true

var _tint: ColorRect = null
var _content: Control = null
var _content_orig_pos := Vector2(0, 0)
var _pulse_t := 0.0
var _coin_accum := 0.0
var _ended := false

const COIN_PARTICLES = preload("res://particles/pickup_gold_particles.tscn")
const COIN_INTERVAL := 1.1
const COIN_COLOR := Color(1.0, 0.78, 0.2)
const TINT_RGB := Color(1.0, 0.35, 0.05)
const TINT_MIN := 0.07
const TINT_MAX := 0.16


func _ready() -> void:
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_content = get_parent() as Control
	if _content != null:
		_content_orig_pos = _content.rect_position

	_build_tint()

	if fresh:
		if intro_enabled:
			_play_flourish()
			_shake()
		if particles_enabled:
			_spawn_coins(10)


# A full-rect tint placed BEHIND the items (first child of Content) but above the
# root Background. Pulsed in _process.
func _build_tint() -> void:
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(TINT_RGB.r, TINT_RGB.g, TINT_RGB.b, TINT_MIN)
	var tint_parent = _content if _content != null else self
	tint_parent.add_child(_tint)
	_tint.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	if _content != null:
		_content.move_child(_tint, 0)


func _process(delta: float) -> void:
	if _ended:
		return

	# Gentle alpha pulse on the background tint.
	_pulse_t += delta * 3.0
	if _tint != null and is_instance_valid(_tint):
		_tint.color.a = TINT_MIN + (TINT_MAX - TINT_MIN) * (0.5 + 0.5 * sin(_pulse_t))

	# Periodic coin bursts for the duration of the sale.
	if particles_enabled:
		_coin_accum += delta
		if _coin_accum >= COIN_INTERVAL:
			_coin_accum = 0.0
			_spawn_coins(4)


# --- intro flourish (one-time) ---

func _play_flourish() -> void:
	# Warm screen flash that fades out.
	var flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.6, 0.2, 0.5)
	add_child(flash)
	flash.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_tween(flash, "color:a", 0.5, 0.0, 0.35)

	# Big "FIRE SALE!" that slams in, holds, then fades.
	var lbl = Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = tr("FIRE_SALE_TITLE") + "!"
	lbl.align = Label.ALIGN_CENTER
	lbl.valign = Label.VALIGN_CENTER
	lbl.add_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.add_color_override("font_color_shadow", Color(0, 0, 0))
	lbl.add_constant_override("shadow_offset_x", 3)
	lbl.add_constant_override("shadow_offset_y", 3)
	var f = _scaled_font(2.6)
	if f != null:
		lbl.add_font_override("font", f)
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.34
	lbl.anchor_bottom = 0.34
	lbl.margin_left = -400
	lbl.margin_right = 400
	lbl.margin_top = -70
	lbl.margin_bottom = 70
	lbl.rect_pivot_offset = Vector2(400, 70)
	add_child(lbl)

	var tw = Tween.new()
	add_child(tw)
	tw.interpolate_property(lbl, "rect_scale", Vector2(1.6, 1.6), Vector2(1, 1), 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.interpolate_property(lbl, "modulate:a", 0.0, 1.0, 0.15, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tw.interpolate_property(lbl, "modulate:a", 1.0, 0.0, 0.5, Tween.TRANS_QUAD, Tween.EASE_IN, 1.1)
	tw.start()


# Brief positional jitter of the whole shop, returning to the original position.
# Respects the player's "Screen shake" accessibility setting.
func _shake() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	if not ProgressData.settings.get("screenshake", true):
		return
	var tw = Tween.new()
	add_child(tw)
	var offsets = [Vector2(9, -6), Vector2(-8, 5), Vector2(6, 5), Vector2(-5, -4), Vector2(3, 2), Vector2(0, 0)]
	var t := 0.0
	var prev = _content_orig_pos
	for off in offsets:
		var target = _content_orig_pos + off
		tw.interpolate_property(_content, "rect_position", prev, target, 0.05, Tween.TRANS_SINE, Tween.EASE_IN_OUT, t)
		prev = target
		t += 0.05
	tw.start()


# --- particles ---

func _spawn_coins(count: int) -> void:
	if shop == null or not is_instance_valid(shop) or not shop.has_method("add_floating_text"):
		return
	var size = get_viewport_rect().size
	var w: float = size.x
	var h: float = size.y
	for i in count:
		var p = COIN_PARTICLES.instance()
		p.color = COIN_COLOR
		shop.add_floating_text(p)
		# Alternate between a top band and a bottom band across the screen.
		var y: float
		if i % 2 == 0:
			y = rand_range(40, 140)
		else:
			y = rand_range(h - 140, h - 40)
		p.global_position = Vector2(rand_range(w * 0.08, w * 0.92), y)
		# Free the standalone particle after it finishes (we're not using the pool).
		var timer = get_tree().create_timer(1.3)
		timer.connect("timeout", p, "queue_free")
		if p.has_method("restart"):
			p.restart()


# --- teardown ---

# Called by the BaseShop extension when the sale ends.
func on_expired() -> void:
	if _ended:
		return
	_ended = true
	if _content != null and is_instance_valid(_content):
		_content.rect_position = _content_orig_pos
	if _tint != null and is_instance_valid(_tint):
		var tw = Tween.new()
		add_child(tw)
		tw.interpolate_property(_tint, "color:a", _tint.color.a, 0.0, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tw.start()
		tw.connect("tween_completed", self, "_free_all")
	else:
		_free_all()


func _free_all(_obj = null, _key = null) -> void:
	if _tint != null and is_instance_valid(_tint):
		_tint.queue_free()
	queue_free()


# Safety net: if we're freed via scene change (GO) rather than on_expired(), make
# sure the shop position is restored. The tint is a child of Content, so it's freed
# with the scene automatically.
func _exit_tree() -> void:
	if _content != null and is_instance_valid(_content):
		_content.rect_position = _content_orig_pos


# --- helpers ---

func _tween(node: Object, prop: String, from, to, dur: float) -> void:
	var tw = Tween.new()
	add_child(tw)
	tw.interpolate_property(node, prop, from, to, dur, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tw.start()


func _scaled_font(factor: float):
	var src: Label = _find_label(shop)
	if src == null:
		return null
	var fnt = src.get_font("font")
	if fnt != null and fnt is DynamicFont:
		var nf: DynamicFont = fnt.duplicate()
		nf.size = int(max(8, fnt.size * factor))
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
