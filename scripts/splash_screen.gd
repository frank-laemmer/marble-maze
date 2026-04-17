extends Control

## Main menu / splash screen.
## Arrow keys / D-pad navigate, Enter / controller A activates, Escape closes panels.

var _level_panel: Control = null
var _controls_panel: Control = null
var _about_panel: Control = null
var _options_panel: Control = null
var _play_btn: Button = null

var _bg_cam: Camera3D = null
var _bg_marble: MeshInstance3D = null
var _bg_yaw: float = 0.0

func _ready() -> void:
	_build_ui()

func _process(delta: float) -> void:
	if _bg_cam == null:
		return
	_bg_yaw += delta * 0.22
	var dist := 3.2
	_bg_cam.position = Vector3(sin(_bg_yaw) * dist, 1.1, cos(_bg_yaw) * dist)
	_bg_cam.look_at(Vector3(0.0, 0.1, 0.0), Vector3.UP)
	if _bg_marble:
		_bg_marble.rotation.x += delta * 0.14
		_bg_marble.rotation.z += delta * 0.06

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _level_panel:
		_level_panel.queue_free()
		_level_panel = null
		_play_btn.grab_focus()
	elif event.is_action_pressed("ui_cancel") and _controls_panel:
		_controls_panel.queue_free()
		_controls_panel = null
		_play_btn.grab_focus()
	elif event.is_action_pressed("ui_cancel") and _about_panel:
		_about_panel.queue_free()
		_about_panel = null
		_play_btn.grab_focus()
	elif event.is_action_pressed("ui_cancel") and _options_panel:
		_options_panel.queue_free()
		_options_panel = null
		_play_btn.grab_focus()

func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# Apply Arial as the default font for all child nodes via the theme
	var t := Theme.new()
	t.default_font = _make_font(400)
	theme = t

	# ── 3D marble background ───────────────────────────────────────────────────
	add_child(_build_bg_viewport())

	# ── Left panel backdrop ────────────────────────────────────────────────────
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.03, 0.03, 0.07, 0.91)
	panel_bg.anchor_left   = 0.0; panel_bg.anchor_right  = 0.0
	panel_bg.anchor_top    = 0.0; panel_bg.anchor_bottom = 1.0
	panel_bg.offset_right  = 540
	add_child(panel_bg)

	# ── Menu column ────────────────────────────────────────────────────────────
	var col := VBoxContainer.new()
	col.anchor_left   = 0.0; col.anchor_right  = 0.0
	col.anchor_top    = 0.0; col.anchor_bottom = 1.0
	col.offset_left   = 52;  col.offset_right  = 516
	add_child(col)

	_vgap(col, 88)

	var title := Label.new()
	title.text = "Marble Maze"
	title.add_theme_font_override("font", _make_font(700))
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	col.add_child(title)

	_vgap(col, 5)

	var sub := Label.new()
	sub.text = "A 3D marble maze game by Claude, Frank, Martha & Falk"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.36, 0.36, 0.52))
	col.add_child(sub)

	_vgap(col, 60)

	_play_btn          = _big_btn("Play")
	var edit_btn       := _big_btn("Level editor")
	var how_btn        := _big_btn("How to play")
	var options_btn    := _big_btn("Options")
	var about_btn      := _big_btn("About")
	var quit_btn       := _big_btn("Quit")

	_play_btn.pressed.connect(_show_level_panel)
	edit_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/level_editor.tscn"))
	how_btn.pressed.connect(_show_controls_panel)
	options_btn.pressed.connect(_show_options_panel)
	about_btn.pressed.connect(_show_about_panel)
	quit_btn.pressed.connect(get_tree().quit)

	for b in [_play_btn, edit_btn, how_btn, options_btn, about_btn]:
		col.add_child(b); _vgap(col, 3)
	col.add_child(quit_btn)

	_play_btn.grab_focus()

func _big_btn(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _make_font(600))
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.82, 0.82, 0.94))
	b.focus_mode = Control.FOCUS_ALL

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	s.content_margin_left = 22
	b.add_theme_stylebox_override("normal", s)

	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.10, 0.10, 0.18, 0.55)
	h.border_width_left = 3
	h.border_color = Color(0.55, 0.58, 0.88)
	h.content_margin_left = 26
	b.add_theme_stylebox_override("hover", h)

	var f := h.duplicate() as StyleBoxFlat
	f.border_color = Color(0.80, 0.82, 1.0)
	b.add_theme_stylebox_override("focus", f)

	var p := f.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.14, 0.14, 0.24, 0.7)
	b.add_theme_stylebox_override("pressed", p)

	return b

func _vgap(parent: VBoxContainer, h: int) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

# ── Level selection overlay ────────────────────────────────────────────────────

func _show_level_panel() -> void:
	if _level_panel:
		_level_panel.queue_free()
	_level_panel = _build_level_panel()
	add_child(_level_panel)

func _build_level_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.96)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Select a Level"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.88, 0.82, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var levels := _collect_levels()
	var first_btn: Button = null
	for lvl in levels:
		var lpath: String    = lvl.path
		var ldisplay: String = lvl.display
		var unlocked: bool   = GameState.is_level_unlocked(lpath)
		var is_custom: bool  = lpath.begins_with("user://")
		var label: String    = ldisplay if unlocked else ldisplay + "  (locked)"
		var b := _level_btn(label, unlocked)
		if unlocked:
			b.pressed.connect(func(): _start_level(lpath))

		if is_custom:
			var row := HBoxContainer.new()
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			var del := _del_btn()
			del.pressed.connect(func(): _confirm_delete(lpath, ldisplay, panel))
			row.add_child(del)
			list.add_child(row)
		else:
			list.add_child(b)

		if first_btn == null and unlocked:
			first_btn = b

	if levels.is_empty():
		var empty := Label.new()
		empty.text = "\nNo levels found.\nCreate one in the editor!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
		empty.add_theme_font_size_override("font_size", 18)
		list.add_child(empty)

	var back := _level_btn("← Back")
	back.pressed.connect(func():
		panel.queue_free()
		_level_panel = null
		_play_btn.grab_focus())
	vbox.add_child(back)

	# Focus first level, or Back if list is empty
	panel.ready.connect(func():
		if first_btn:
			first_btn.grab_focus()
		else:
			back.grab_focus())

	return panel

func _level_btn(label: String, unlocked: bool = true) -> Button:
	var b := Button.new()
	b.text = "   " + label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_ALL

	if unlocked:
		b.add_theme_color_override("font_color", Color.WHITE)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.14, 0.14, 0.22)
		b.add_theme_stylebox_override("normal", s)

		var h := s.duplicate() as StyleBoxFlat
		h.bg_color = Color(0.22, 0.22, 0.34)
		b.add_theme_stylebox_override("hover", h)

		var f := s.duplicate() as StyleBoxFlat
		f.bg_color = Color(0.18, 0.18, 0.30)
		f.border_color = Color(1.0, 1.0, 1.0, 0.85)
		f.border_width_left   = 3; f.border_width_right  = 3
		f.border_width_top    = 3; f.border_width_bottom = 3
		b.add_theme_stylebox_override("focus", f)
	else:
		b.disabled = true
		b.add_theme_color_override("font_color", Color(0.38, 0.38, 0.50))
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.09, 0.09, 0.14)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("disabled", s)

	return b

func _del_btn() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.07, 0.07)
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.38, 0.12, 0.12)
	b.add_theme_stylebox_override("hover", h)
	return b

func _confirm_delete(path: String, display: String, parent: Control) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.10, 0.97)
	overlay.add_theme_stylebox_override("panel", style)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.anchor_left = 0.5; center.anchor_right  = 0.5
	center.anchor_top  = 0.5; center.anchor_bottom = 0.5
	center.offset_left = -260; center.offset_right  = 260
	center.offset_top  = -110; center.offset_bottom = 110
	overlay.add_child(center)

	var msg := Label.new()
	msg.text = "Delete this level?\n\n" + display + "\n\nThis cannot be undone."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(msg)
	_vgap(center, 22)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	var del_btn := _big_btn("Delete")
	del_btn.pressed.connect(func():
		DirAccess.remove_absolute(path)
		_show_level_panel()   # rebuilds the list; also frees the old panel + this overlay
	)
	row.add_child(del_btn)

	var gap := Control.new(); gap.custom_minimum_size = Vector2(16, 0)
	row.add_child(gap)

	var cancel_btn := _big_btn("Cancel")
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	row.add_child(cancel_btn)

	parent.add_child(overlay)
	cancel_btn.grab_focus()

func _collect_levels() -> Array:
	var out: Array = []
	for pair in [["res://levels/", "[Built-in]  "], ["user://levels/", "[Custom]     "]]:
		var d := DirAccess.open(pair[0])
		if not d: continue
		var files: Array[String] = []
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			if fn.ends_with(".txt"):
				files.append(fn)
			fn = d.get_next()
		files.sort()
		for f in files:
			var path: String = pair[0] + f
			var lvl_name: String = _read_level_name(path)
			var label: String = lvl_name if lvl_name != "" else f.get_basename()
			out.append({"path": path, "display": pair[1] + label})
	return out

## Read the !name= metadata from a level file without fully parsing it.
func _read_level_name(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("!name="):
			file.close()
			return line.substr(6)
		elif not line.begins_with("!") and line != "":
			break  # reached grid content, no name found
	file.close()
	return ""

func _start_level(path: String) -> void:
	GameState.level_path = path
	GameState.from_editor = false
	GameState.editor_level_content = ""
	GameState.entry_mode = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

# ── Controls / How To Play overlay ────────────────────────────────────────────

func _show_controls_panel() -> void:
	if _controls_panel:
		_controls_panel.queue_free()
	_controls_panel = _build_doc_panel("res://content/how_to_play.md", func():
		_controls_panel.queue_free()
		_controls_panel = null
		_play_btn.grab_focus())
	add_child(_controls_panel)

# ── Options overlay ────────────────────────────────────────────────────────────

func _show_options_panel() -> void:
	if _options_panel:
		_options_panel.queue_free()
	_options_panel = _build_options_panel()
	add_child(_options_panel)

func _build_options_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.96)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   80)
	margin.add_theme_constant_override("margin_right",  80)
	margin.add_theme_constant_override("margin_top",    60)
	margin.add_theme_constant_override("margin_bottom", 60)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.88, 0.82, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	_vgap(vbox, 32)

	# ── Controls section ──────────────────────────────────────────────────────
	var ctrl_section := Label.new()
	ctrl_section.text = "CONTROLS"
	ctrl_section.add_theme_font_size_override("font_size", 20)
	ctrl_section.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	vbox.add_child(ctrl_section)
	_vgap(vbox, 12)

	# Helper: build the touch-toggle label reflecting current state
	var touch_label := func() -> String:
		var auto_on := DisplayServer.is_touchscreen_available() \
				or OS.has_feature("mobile") \
				or OS.has_feature("web_android") \
				or OS.has_feature("web_ios")
		if auto_on and not GameState.touch_enabled:
			return "Touch Controls:  Auto (On)"
		return "Touch Controls:  " + ("On" if GameState.touch_enabled else "Off")

	var touch_btn := _big_btn(touch_label.call())
	touch_btn.pressed.connect(func():
		GameState.touch_enabled = not GameState.touch_enabled
		GameState.save_settings()
		touch_btn.text = touch_label.call())
	vbox.add_child(touch_btn)
	_vgap(vbox, 6)

	var lh_btn := _big_btn("Left-Hand Mode (joystick right):  " \
			+ ("On" if GameState.touch_left_handed else "Off"))
	lh_btn.pressed.connect(func():
		GameState.touch_left_handed = not GameState.touch_left_handed
		GameState.save_settings()
		lh_btn.text = "Left-Hand Mode (joystick right):  " \
				+ ("On" if GameState.touch_left_handed else "Off"))
	vbox.add_child(lh_btn)
	_vgap(vbox, 32)

	# ── Progress section ───────────────────────────────────────────────────────
	var section := Label.new()
	section.text = "PROGRESS"
	section.add_theme_font_size_override("font_size", 20)
	section.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	vbox.add_child(section)
	_vgap(vbox, 12)

	var reset_btn := _big_btn("Reset Level Progress")
	reset_btn.pressed.connect(func(): _confirm_reset_progress(panel))
	vbox.add_child(reset_btn)
	_vgap(vbox, 32)

	var back := _big_btn("← BACK")
	back.pressed.connect(func():
		panel.queue_free()
		_options_panel = null
		_play_btn.grab_focus())
	vbox.add_child(back)

	panel.ready.connect(func(): touch_btn.grab_focus())
	return panel

func _confirm_reset_progress(parent: Control) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.10, 0.97)
	overlay.add_theme_stylebox_override("panel", style)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.anchor_left = 0.5; center.anchor_right  = 0.5
	center.anchor_top  = 0.5; center.anchor_bottom = 0.5
	center.offset_left = -260; center.offset_right  = 260
	center.offset_top  = -110; center.offset_bottom = 110
	overlay.add_child(center)

	var msg := Label.new()
	msg.text = "Reset all level progress?\n\nAll built-in levels will be locked again.\nThis cannot be undone."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(msg)
	_vgap(center, 22)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	var confirm_btn := _big_btn("Reset")
	confirm_btn.pressed.connect(func():
		GameState.reset_progress()
		overlay.queue_free())
	row.add_child(confirm_btn)

	var gap := Control.new(); gap.custom_minimum_size = Vector2(16, 0)
	row.add_child(gap)

	var cancel_btn := _big_btn("Cancel")
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	row.add_child(cancel_btn)

	parent.add_child(overlay)
	cancel_btn.grab_focus()

# ── About overlay ──────────────────────────────────────────────────────────────

func _show_about_panel() -> void:
	if _about_panel:
		_about_panel.queue_free()
	_about_panel = _build_doc_panel("res://content/about.md", func():
		_about_panel.queue_free()
		_about_panel = null
		_play_btn.grab_focus())
	add_child(_about_panel)

# ── Generic document panel (reads a .md file and renders it) ──────────────────

func _build_doc_panel(file_path: String, close_callback: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.96)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   80)
	margin.add_theme_constant_override("margin_right",  80)
	margin.add_theme_constant_override("margin_top",    48)
	margin.add_theme_constant_override("margin_bottom", 48)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		_render_doc(content, file.get_as_text())
		file.close()
	else:
		var err := Label.new()
		err.text = "Content file not found:\n" + file_path
		err.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		content.add_child(err)

	_vgap(outer, 16)
	var back := _big_btn("← BACK")
	back.pressed.connect(close_callback)
	outer.add_child(back)

	panel.ready.connect(func(): back.grab_focus())
	return panel

## Render simple markdown into a VBoxContainer.
## Supported syntax:
##   # Title         — large centred heading
##   ## Section      — cyan section heading
##   ---             — horizontal separator
##   (blank line)    — vertical gap
##   [text](url)     — clickable hyperlink (inline, anywhere in a line)
##   any other       — body text (auto-wraps)
func _render_doc(parent: VBoxContainer, text: String) -> void:
	for line in text.split("\n"):
		if line.begins_with("# "):
			var lbl := Label.new()
			lbl.text = line.substr(2)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 36)
			lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 1.0))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			parent.add_child(lbl)
			_vgap(parent, 12)
		elif line.begins_with("## "):
			_vgap(parent, 6)
			var lbl := Label.new()
			lbl.text = line.substr(3)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			parent.add_child(lbl)
		elif line.strip_edges() == "---":
			_vgap(parent, 8)
			parent.add_child(HSeparator.new())
			_vgap(parent, 8)
		elif line.strip_edges().is_empty():
			_vgap(parent, 10)
		else:
			var bbcode := _md_links_to_bbcode(line)
			if bbcode != line:
				# Line contains at least one markdown link — use RichTextLabel
				var rtl := RichTextLabel.new()
				rtl.bbcode_enabled  = true
				rtl.text            = bbcode
				rtl.fit_content     = true
				rtl.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
				rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rtl.add_theme_font_size_override("normal_font_size", 17)
				rtl.add_theme_color_override("default_color", Color(0.82, 0.82, 0.92))
				rtl.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
				parent.add_child(rtl)
			else:
				var lbl := Label.new()
				lbl.text = line
				lbl.add_theme_font_size_override("font_size", 17)
				lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.92))
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				parent.add_child(lbl)

## Convert markdown link syntax [label](url) to BBCode [url=url]label[/url].
## Returns the original string unchanged if no links are found.
func _md_links_to_bbcode(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	return re.sub(text, "[color=#6ab4ff][url=$2]$1[/url][/color]", true)

# ── Background 3D scene ────────────────────────────────────────────────────────

func _build_bg_viewport() -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true

	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	var root := Node3D.new()
	sv.add_child(root)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.30, 0.48)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_density = 0.05
	env.fog_light_color = Color(0.05, 0.05, 0.12)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# Key light
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 55, 0)
	key.light_energy = 2.0
	key.light_color = Color(1.0, 0.93, 0.86)
	key.shadow_enabled = true
	root.add_child(key)

	# Rim / fill light
	var rim := OmniLight3D.new()
	rim.position = Vector3(-4, 3, -3)
	rim.light_energy = 2.5
	rim.light_color = Color(0.35, 0.42, 0.90)
	rim.omni_range = 14.0
	root.add_child(rim)

	# Floor
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30, 30)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.07, 0.12)
	floor_mat.roughness = 0.85
	floor_mat.metallic = 0.15
	floor_mesh.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(0, -1.05, 0)
	root.add_child(floor_mi)

	# Marble sphere
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var marble_mat := ShaderMaterial.new()
	marble_mat.shader = preload("res://shaders/marble.gdshader")
	_bg_marble = MeshInstance3D.new()
	_bg_marble.mesh = sphere
	_bg_marble.material_override = marble_mat
	root.add_child(_bg_marble)

	# Camera — initial position; updated each frame by _process
	_bg_cam = Camera3D.new()
	_bg_cam.fov = 52.0
	_bg_cam.h_offset = -1.1  # shift frustum left so marble appears in the right portion
	_bg_cam.position = Vector3(0, 1.1, 3.2)
	_bg_cam.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	root.add_child(_bg_cam)

	return svc

## Returns an Arial system font at the requested weight.
func _make_font(weight: int = 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Helvetica", "Arial", "Liberation Sans", "sans-serif"])
	f.font_weight = weight
	return f
