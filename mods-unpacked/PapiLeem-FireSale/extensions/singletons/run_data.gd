# run_data.gd extension - persists an active Fire Sale across save/load.
#
# RunData.get_state() is a hardcoded dict and resume_from_state() reads explicit
# keys, so a new field is ignored unless both are extended. get_state() flows
# through ProgressData.get_run_state() into every save point (shop _ready, on
# pause, on GO) and the in-shop "continue run" resume path, so no extra save calls
# are needed.

extends "res://singletons/run_data.gd"


func _get_fss():
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("FireSaleState")
	return null


func get_state() -> Dictionary:
	var s = .get_state()
	var fss = _get_fss()
	if fss != null:
		s["fire_sale"] = fss.serialize()
	return s


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	var fss = _get_fss()
	if fss != null and state.has("fire_sale"):
		fss.deserialize(state["fire_sale"])
