extends CanvasLayer

@onready var timer_label:    Label     = $TimerLabel
@onready var overlay:        Control   = $Overlay
@onready var overlay_bg:     ColorRect = $Overlay/ColorRect
@onready var overlay_label:  Label     = $Overlay/OverlayLabel
@onready var minimap_panel:  Control   = $MinimapPanel

var _key_bar:    Control  # outer container (shown/hidden)
var _key_icons:  HBoxContainer


func _ready() -> void:
	overlay.hide()
	minimap_panel.visible = LevelLoader.level_show_minimap
	_build_key_bar()

	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm:
		lm.time_changed.connect(_on_time_changed)
		lm.state_changed.connect(_on_state_changed)

		if GameState.FEATURE_KEYS_DOORS:
			lm.keys_changed.connect(_on_keys_changed)


# ── Key inventory bar ──────────────────────────────────────────────────────────

func _build_key_bar() -> void:
	# Anchored to the bottom-left corner.
	var bar := MarginContainer.new()
	bar.anchor_left   = 0.0
	bar.anchor_right  = 0.0
	bar.anchor_top    = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left   = 14
	bar.offset_right  = 250
	bar.offset_top    = -58
	bar.offset_bottom = -14

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.10, 0.80)
	bg.set_corner_radius_all(5)
	bg.content_margin_left   = 8
	bg.content_margin_right  = 8
	bg.content_margin_top    = 5
	bg.content_margin_bottom = 5

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	bar.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hbox)

	# Static "KEY" label
	var lbl := Label.new()
	lbl.text = "KEY "
	lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.80))
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)

	# Dynamic icons container — one gold chip per key held.
	_key_icons = HBoxContainer.new()
	_key_icons.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_child(_key_icons)

	bar.hide()
	_key_bar = bar
	add_child(bar)


func _on_keys_changed(counts: Dictionary) -> void:
	for child in _key_icons.get_children():
		child.queue_free()

	var total := 0
	for v in counts.values():
		total += v
	if total <= 0:
		_key_bar.hide()
		return

	for pair in [
		["yellow", Color(0.90, 0.72, 0.10)],
		["green",  Color(0.18, 0.80, 0.26)],
		["red",    Color(0.88, 0.18, 0.18)],
	]:
		var c: int = counts.get(pair[0], 0)
		for i in c:
			_key_icons.add_child(_make_key_chip(pair[1]))

	_key_bar.show()


func _make_key_chip(chip_color: Color = Color(0.90, 0.72, 0.10)) -> Control:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(22, 28)

	var s := StyleBoxFlat.new()
	s.bg_color = chip_color
	s.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", s)

	var slot := Label.new()
	slot.text = "⚿"
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	slot.add_theme_color_override("font_color", Color(0.06, 0.06, 0.10))
	slot.add_theme_font_size_override("font_size", 14)
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(slot)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)

	var row := HBoxContainer.new()
	row.add_child(chip)
	row.add_child(spacer)
	return row


# ── Timer / overlay ───────────────────────────────────────────────────────────

func _on_time_changed(t: float) -> void:
	t = max(t, 0.0)
	var minutes := int(t) / 60
	var seconds  := int(t) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	if t < 10.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	elif t < 30.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))


func _on_state_changed(s: int) -> void:
	match s:
		0:  # PLAYING — entry countdown ended, clear the overlay
			overlay.hide()

		1:  # FAIL
			overlay_bg.color = Color(0.0, 0.0, 0.0, 0.6)
			var retry_hint := "Tap screen  or  press R / Start to try again" \
					if GameState.is_touch_active() \
					else "Press R / Start to try again"
			overlay_label.text = "TIME'S UP!\n\n" + retry_hint
			overlay_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			overlay.show()

		2:  # ENTRY — no dark overlay, just the level name if there is one
			var title := GameState.level_title.strip_edges()
			if title != "":
				overlay_bg.color = Color(0.0, 0.0, 0.0, 0.0)
				overlay_label.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
				overlay_label.text = title
				overlay.show()
			# If there is no title, show nothing at all during the flyover.

