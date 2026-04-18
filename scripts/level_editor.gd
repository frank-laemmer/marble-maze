extends Control

## In-game level editor.
## Tile legend saved to file:
##   S  start    G  end/goal    #  wall    .  floor    _  empty (no floor)
##   I  invisible wall (collision, no mesh)    F  fake wall (mesh, no collision)
##   K  key item (collectible)
##   D  door N/S (halves slide north & south on opening)
##   H  door E/W (halves slide east & west on opening)
## Metadata header lines (prefix !):
##   !name=<display title>   !timer=<seconds>

enum TileType { EMPTY = 0, FLOOR = 1, WALL = 2, START = 3, END = 4, MAP = 5, INVIS_WALL = 6, FAKE_WALL = 7, KEY_Y = 8, DOOR_Y = 9, INVIS_FLOOR = 10, KEY_G = 11, DOOR_G = 12, KEY_R = 13, DOOR_R = 14 }

const TILE_LABELS  : Array = ["Empty", "Floor", "Wall", "Start", "End", "Map Tile", "Invis Wall", "Fake Wall", "Key (Yellow)", "Door (Yellow)", "Invis Floor", "Key (Green)", "Door (Green)", "Key (Red)", "Door (Red)"]
const TILE_COLORS  : Array = [
	Color(0.10, 0.10, 0.13),
	Color(0.65, 0.65, 0.65),
	Color(0.38, 0.38, 0.38),
	Color(0.15, 0.78, 0.22),
	Color(0.88, 0.73, 0.08),
	Color(0.15, 0.65, 0.72),  # MAP        — teal
	Color(0.38, 0.62, 0.88),  # INVIS_WALL — steel blue
	Color(0.58, 0.30, 0.68),  # FAKE_WALL  — purple
	Color(0.92, 0.74, 0.10),  # KEY_Y      — gold
	Color(0.20, 0.38, 0.62),  # DOOR_Y     — dark blue
	Color(0.38, 0.38, 0.38),  # INVIS_FLOOR — neutral grey
	Color(0.18, 0.72, 0.26),  # KEY_G      — green
	Color(0.14, 0.34, 0.20),  # DOOR_G     — dark green
	Color(0.82, 0.18, 0.18),  # KEY_R      — red
	Color(0.36, 0.14, 0.14),  # DOOR_R     — dark red
]
const TILE_CHARS   : Array = ["_", ".", "#", "S", "G", "M", "I", "F", "K", "D", "V", "J", "E", "X", "R"]

const MAX_ROWS := 50
const MAX_COLS := 50
const MIN_DIM  := 3
const DEFAULT_DIM := 15

# ── State ──────────────────────────────────────────────────────────────────────

var grid: Array = []
var grid_rows: int = DEFAULT_DIM
var grid_cols: int = DEFAULT_DIM
var current_tool: int = TileType.FLOOR
var level_name: String = "my_level"   # file basename (used for save path)
var level_title: String = ""           # display name stored as !name= metadata
var level_timer: int = 180             # time limit stored as !timer= metadata
var level_tilt_x: int = 0  # degrees around X axis; stored as !tilt=x,z
var level_tilt_z: int = 0  # degrees around Z axis
var level_marble_type: String = "sphere"  # stored as !marble=; "sphere"|"dice"
var level_marble_size: float = 1.0        # stored as !marble_size=; 0.1–5.0
var has_start: bool = false
var has_end:   bool = false

# ── UI references ──────────────────────────────────────────────────────────────

var _grid_canvas: Control
var _scroll: ScrollContainer
var _status_label: Label
var _name_edit: LineEdit
var _title_edit: LineEdit
var _timer_spin: SpinBox
var _tilt_x_spin: SpinBox
var _tilt_z_spin: SpinBox
var _marble_option: OptionButton
var _marble_size_spin: SpinBox
var _rows_spin: SpinBox
var _cols_spin: SpinBox
var _tile_buttons: Array = []
var _cell_size_label: Label
var _load_overlay: Control = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_grid(DEFAULT_DIM, DEFAULT_DIM)
	_build_ui()

	# Restore level when returning from an editor test-play
	if GameState.from_editor and not GameState.editor_level_content.is_empty():
		_load_from_string(GameState.editor_level_content)
		if not GameState.editor_level_name.is_empty():
			level_name = GameState.editor_level_name
			if _name_edit: _name_edit.text = level_name
		GameState.editor_level_content = ""
		GameState.editor_level_name = ""
		GameState.from_editor = false

# ── Grid data ──────────────────────────────────────────────────────────────────

func _init_grid(rows: int, cols: int) -> void:
	grid_rows = clampi(rows, MIN_DIM, MAX_ROWS)
	grid_cols = clampi(cols, MIN_DIM, MAX_COLS)
	grid      = []
	has_start = false
	has_end   = false
	for _r in grid_rows:
		var row_arr: Array = []
		for _c in grid_cols:
			row_arr.append(TileType.EMPTY)
		grid.append(row_arr)

## Called by GridCanvas on every painted cell
func set_cell(row: int, col: int, tile: int) -> void:
	if row < 0 or row >= grid_rows or col < 0 or col >= grid_cols:
		return

	# Enforce single-instance tiles
	if tile == TileType.START and has_start:
		_clear_tile_type(TileType.START)
	if tile == TileType.END and has_end:
		_clear_tile_type(TileType.END)

	var old: int = grid[row][col]
	if old == TileType.START: has_start = false
	if old == TileType.END:   has_end   = false

	grid[row][col] = tile
	if tile == TileType.START: has_start = true
	if tile == TileType.END:   has_end   = true

	_refresh_status()

func _clear_tile_type(tile: int) -> void:
	for r in grid_rows:
		for c in grid_cols:
			if grid[r][c] == tile:
				grid[r][c] = TileType.FLOOR

func _resize_grid(new_rows: int, new_cols: int) -> void:
	new_rows = clampi(new_rows, MIN_DIM, MAX_ROWS)
	new_cols = clampi(new_cols, MIN_DIM, MAX_COLS)
	var old   := grid.duplicate(true)
	var old_r := grid_rows
	var old_c := grid_cols
	_init_grid(new_rows, new_cols)
	for r in mini(new_rows, old_r):
		for c in mini(new_cols, old_c):
			var t: int = old[r][c]
			grid[r][c] = t
			if t == TileType.START: has_start = true
			if t == TileType.END:   has_end   = true
	_sync_canvas()
	_refresh_status()

# ── Serialisation ──────────────────────────────────────────────────────────────

func _level_to_string() -> String:
	var lines: Array = []
	# Write metadata header
	var title := level_title.strip_edges()
	if title.is_empty():
		title = level_name
	lines.append("!name=" + title)
	lines.append("!timer=" + str(level_timer))
	if level_tilt_x != 0 or level_tilt_z != 0:
		lines.append("!tilt=" + str(level_tilt_x) + "," + str(level_tilt_z))
	if level_marble_type != "sphere":
		lines.append("!marble=" + level_marble_type)
	if level_marble_size != 1.0:
		lines.append("!marble_size=" + str(snappedf(level_marble_size, 0.01)))
	# Write grid rows
	for row in grid:
		var line := ""
		for tile in row:
			line += TILE_CHARS[tile]
		lines.append(line)
	return "\n".join(lines)

func _load_from_string(content: String) -> void:
	var char_to_tile := {"_": TileType.EMPTY, ".": TileType.FLOOR,
						  "#": TileType.WALL,  "S": TileType.START, "G": TileType.END,
						  "M": TileType.MAP, "I": TileType.INVIS_WALL, "F": TileType.FAKE_WALL,
						  "K": TileType.KEY_Y, "J": TileType.KEY_G, "X": TileType.KEY_R,
						  "D": TileType.DOOR_Y, "H": TileType.DOOR_Y,
						  "E": TileType.DOOR_G, "R": TileType.DOOR_R,
						  "V": TileType.INVIS_FLOOR}
	# Reset metadata before parsing
	level_timer = 180
	level_title = ""
	level_tilt_x = 0
	level_tilt_z = 0
	level_marble_type = "sphere"
	level_marble_size = 1.0

	var rows: Array = []
	for line in content.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("!"):
			# Metadata line — preserve internal spaces (e.g. "!name=Born to roll").
			var kv := trimmed.substr(1).split("=", true, 1)
			if kv.size() == 2:
				match kv[0]:
					"name":  level_title = kv[1]
					"timer": level_timer = kv[1].to_int()
					"tilt":
						var tp := kv[1].split(",")
						level_tilt_x = tp[0].to_int()
						level_tilt_z = tp[1].to_int() if tp.size() > 1 else 0
					"marble":      level_marble_type = kv[1]
					"marble_size": level_marble_size = kv[1].to_float()
		else:
			# Grid row — strip spaces/tabs for backward compat with "S # . #" format.
			var stripped := ""
			for ch in line:
				if ch != " " and ch != "\t" and ch != "\r":
					stripped += ch
			if not stripped.is_empty():
				rows.append(stripped)

	if rows.is_empty():
		return

	var nr := mini(rows.size(), MAX_ROWS)
	var nc := 0
	for row in rows:
		nc = max(nc, (row as String).length())
	nc = mini(nc, MAX_COLS)

	_init_grid(nr, nc)
	for ri in nr:
		for ci in mini((rows[ri] as String).length(), nc):
			var t: int = char_to_tile.get(rows[ri][ci], TileType.FLOOR)
			grid[ri][ci] = t
			if t == TileType.START: has_start = true
			if t == TileType.END:   has_end   = true

	# Sync UI fields
	if _title_edit: _title_edit.text  = level_title
	if _timer_spin: _timer_spin.value = level_timer
	if _tilt_x_spin: _tilt_x_spin.value = level_tilt_x
	if _tilt_z_spin: _tilt_z_spin.value = level_tilt_z
	if _marble_option:
		_marble_option.selected = ({"sphere": 0, "dice": 1} as Dictionary).get(level_marble_type, 0) as int
	if _marble_size_spin: _marble_size_spin.value = level_marble_size
	if _rows_spin:  _rows_spin.value  = grid_rows
	if _cols_spin:  _cols_spin.value  = grid_cols
	_sync_canvas()
	_refresh_status()

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	root_vbox.add_child(_build_toolbar())

	var mid := HSplitContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(mid)

	mid.add_child(_build_palette())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	mid.add_child(_scroll)

	# Grid canvas
	var GridCanvasScript := preload("res://scripts/grid_canvas.gd")
	_grid_canvas = GridCanvasScript.new()
	_grid_canvas.grid         = grid
	_grid_canvas.grid_rows    = grid_rows
	_grid_canvas.grid_cols    = grid_cols
	_grid_canvas.cell_size    = 20
	_grid_canvas.current_tool = current_tool
	_grid_canvas.editor_node  = self
	_scroll.add_child(_grid_canvas)

	root_vbox.add_child(_build_statusbar())
	_refresh_status()

func _build_toolbar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	_panel_bg(panel, Color(0.12, 0.12, 0.18))

	var rows_vbox := VBoxContainer.new()
	rows_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(rows_vbox)

	# ── Row 1: actions + file naming + timer ──────────────────────────────────
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	rows_vbox.add_child(row1)

	_hspace(row1, 6)
	for pair in [
		["New",    Color(0.24, 0.34, 0.54), _on_new],
		["Load",   Color(0.24, 0.34, 0.54), _on_load],
		["Save",   Color(0.18, 0.52, 0.28), _on_save],
		["Test",   Color(0.52, 0.34, 0.14), _on_play],
		["Menu",   Color(0.32, 0.22, 0.40), _on_back],
	]:
		var b := _btn(pair[0], pair[1])
		b.pressed.connect(pair[2])
		row1.add_child(b)
		_hspace(row1, 4)

	if not OS.has_feature("web"):
		_hspace(row1, 4)
		var stock_btn := _btn("Stock", Color(0.42, 0.28, 0.58))
		stock_btn.tooltip_text = "Save to res://levels/ (developer mode)"
		stock_btn.pressed.connect(_on_save_stock)
		row1.add_child(stock_btn)

	_hspace(row1, 14)
	_lbl(row1, "File:")
	_hspace(row1, 4)
	_name_edit = LineEdit.new()
	_name_edit.text = level_name
	_name_edit.custom_minimum_size = Vector2(100, 0)
	_name_edit.placeholder_text = "filename"
	_name_edit.text_changed.connect(func(t: String): level_name = t)
	row1.add_child(_name_edit)
	_hspace(row1, 10)

	_lbl(row1, "Title:")
	_hspace(row1, 4)
	_title_edit = LineEdit.new()
	_title_edit.text = level_title
	_title_edit.custom_minimum_size = Vector2(160, 0)
	_title_edit.placeholder_text = "display name"
	_title_edit.text_changed.connect(func(t: String): level_title = t)
	row1.add_child(_title_edit)
	_hspace(row1, 10)

	_lbl(row1, "Timer:")
	_hspace(row1, 4)
	_timer_spin = SpinBox.new()
	_timer_spin.min_value = 10
	_timer_spin.max_value = 600
	_timer_spin.step = 5
	_timer_spin.value = level_timer
	_timer_spin.suffix = "s"
	_timer_spin.custom_minimum_size = Vector2(86, 0)
	_timer_spin.value_changed.connect(func(v: float): level_timer = int(v))
	row1.add_child(_timer_spin)

	# ── Row 2: level parameters + grid size + zoom ────────────────────────────
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_BEGIN
	rows_vbox.add_child(row2)

	_hspace(row2, 6)
	_lbl(row2, "Tilt X:")
	_hspace(row2, 4)
	_tilt_x_spin = SpinBox.new()
	_tilt_x_spin.min_value = -60
	_tilt_x_spin.max_value = 60
	_tilt_x_spin.step = 1
	_tilt_x_spin.value = level_tilt_x
	_tilt_x_spin.suffix = "°"
	_tilt_x_spin.custom_minimum_size = Vector2(74, 0)
	_tilt_x_spin.value_changed.connect(func(v: float): level_tilt_x = int(v))
	row2.add_child(_tilt_x_spin)
	_hspace(row2, 8)

	_lbl(row2, "Z:")
	_hspace(row2, 4)
	_tilt_z_spin = SpinBox.new()
	_tilt_z_spin.min_value = -60
	_tilt_z_spin.max_value = 60
	_tilt_z_spin.step = 1
	_tilt_z_spin.value = level_tilt_z
	_tilt_z_spin.suffix = "°"
	_tilt_z_spin.custom_minimum_size = Vector2(74, 0)
	_tilt_z_spin.value_changed.connect(func(v: float): level_tilt_z = int(v))
	row2.add_child(_tilt_z_spin)
	_hspace(row2, 14)

	_lbl(row2, "Marble:")
	_hspace(row2, 4)
	_marble_option = OptionButton.new()
	_marble_option.add_item("Sphere", 0)
	_marble_option.add_item("Dice",   1)
	_marble_option.selected = 0
	_marble_option.custom_minimum_size = Vector2(86, 0)
	_marble_option.item_selected.connect(func(idx: int):
		level_marble_type = ["sphere", "dice"][idx]
		_refresh_status())
	row2.add_child(_marble_option)
	_hspace(row2, 8)

	_lbl(row2, "Size:")
	_hspace(row2, 4)
	_marble_size_spin = SpinBox.new()
	_marble_size_spin.min_value = 0.1
	_marble_size_spin.max_value = 5.0
	_marble_size_spin.step = 0.1
	_marble_size_spin.value = 1.0
	_marble_size_spin.custom_minimum_size = Vector2(74, 0)
	_marble_size_spin.value_changed.connect(func(v: float):
		level_marble_size = v
		_refresh_status())
	row2.add_child(_marble_size_spin)
	_hspace(row2, 14)

	_lbl(row2, "Grid:")
	_hspace(row2, 4)
	_rows_spin = SpinBox.new()
	_rows_spin.min_value = MIN_DIM; _rows_spin.max_value = MAX_ROWS
	_rows_spin.value = grid_rows; _rows_spin.custom_minimum_size = Vector2(66, 0)
	row2.add_child(_rows_spin)
	_lbl(row2, "x")
	_cols_spin = SpinBox.new()
	_cols_spin.min_value = MIN_DIM; _cols_spin.max_value = MAX_COLS
	_cols_spin.value = grid_cols; _cols_spin.custom_minimum_size = Vector2(66, 0)
	row2.add_child(_cols_spin)
	_hspace(row2, 4)
	var apply := _btn("Apply", Color(0.28, 0.38, 0.58))
	apply.pressed.connect(func(): _resize_grid(int(_rows_spin.value), int(_cols_spin.value)))
	row2.add_child(apply)
	_hspace(row2, 14)

	_lbl(row2, "Zoom:")
	_hspace(row2, 4)
	var z_out := _btn("-", Color(0.22, 0.22, 0.32))
	z_out.custom_minimum_size = Vector2(34, 0)
	z_out.pressed.connect(_zoom_out)
	row2.add_child(z_out)
	_cell_size_label = Label.new(); _cell_size_label.text = "20px"
	_cell_size_label.custom_minimum_size = Vector2(44, 0)
	_cell_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cell_size_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	row2.add_child(_cell_size_label)
	var z_in := _btn("+", Color(0.22, 0.22, 0.32))
	z_in.custom_minimum_size = Vector2(34, 0)
	z_in.pressed.connect(_zoom_in)
	row2.add_child(z_in)

	return panel

func _build_palette() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(152, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_bg(panel, Color(0.10, 0.10, 0.16))

	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(outer)

	var title := Label.new(); title.text = "Tiles"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	title.add_theme_font_size_override("font_size", 15)
	outer.add_child(title)

	# Scrollable area so the palette works on smaller screens.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical          = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode       = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode         = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_tile_buttons.clear()
	for i in TILE_LABELS.size():
		# Hide key/door tiles when the feature is disabled
		if not GameState.FEATURE_KEYS_DOORS and i in [
				TileType.KEY_Y, TileType.DOOR_Y,
				TileType.KEY_G, TileType.DOOR_G,
				TileType.KEY_R, TileType.DOOR_R]:
			_tile_buttons.append(null)
			continue
		var b := Button.new()
		b.text = "  " + TILE_LABELS[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		var idx := i
		b.pressed.connect(func(): _select_tool(idx))
		_tile_buttons.append(b)
		vbox.add_child(b)
		_style_tile_btn(b, i, i == current_tool)

	var hint := Label.new()
	hint.text = "\nLMB paint\nRMB erase\n\nOne Start\n& one End."
	hint.add_theme_color_override("font_color", Color(0.48, 0.48, 0.58))
	hint.add_theme_font_size_override("font_size", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer.add_child(hint)

	return panel

func _build_statusbar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 26)
	_panel_bg(panel, Color(0.10, 0.10, 0.16))

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.82))
	_status_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_status_label)

	return panel

# ── UI helpers ─────────────────────────────────────────────────────────────────

func _btn(label: String, color: Color) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_color_override("font_color", Color.WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = color; s.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color.lightened(0.18)
	b.add_theme_stylebox_override("hover", h)
	return b

func _lbl(parent: HBoxContainer, text: String) -> void:
	var l := Label.new(); l.text = text
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	parent.add_child(l)

func _panel_bg(panel: Control, color: Color) -> void:
	var s := StyleBoxFlat.new(); s.bg_color = color
	panel.add_theme_stylebox_override("panel", s)

func _hspace(parent: HBoxContainer, w: int) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(w, 0)
	parent.add_child(s)

func _style_tile_btn(btn: Button, idx: int, selected: bool) -> void:
	var base: Color = TILE_COLORS[idx]
	var s := StyleBoxFlat.new()
	s.bg_color = base if selected else base.darkened(0.45)
	s.set_corner_radius_all(3)
	if selected:
		s.border_width_left = 3; s.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = base.lightened(0.1) if selected else base.darkened(0.25)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _sync_canvas() -> void:
	if not _grid_canvas:
		return
	_grid_canvas.grid      = grid
	_grid_canvas.grid_rows = grid_rows
	_grid_canvas.grid_cols = grid_cols
	_grid_canvas.refresh()

func _refresh_status() -> void:
	var warn := ""
	if not has_start: warn += "  ! No Start"
	if not has_end:   warn += "  ! No End"
	var tilt_info := ("   Tilt X:%d° Z:%d°" % [level_tilt_x, level_tilt_z]) if (level_tilt_x != 0 or level_tilt_z != 0) else ""
	var marble_info := ("   Marble:%s" % level_marble_type) if level_marble_type != "sphere" else ""
	if level_marble_size != 1.0:
		marble_info += "   Size:x%.1f" % level_marble_size
	_status_label.text = "  Tool: %s   Grid: %d x %d   File: \"%s\"   Timer: %ds%s%s%s" % [
		TILE_LABELS[current_tool], grid_cols, grid_rows, level_name, level_timer, tilt_info, marble_info, warn
	]

# ── Tool / zoom ────────────────────────────────────────────────────────────────

func _select_tool(idx: int) -> void:
	current_tool = idx
	_grid_canvas.current_tool = idx
	for i in _tile_buttons.size():
		if _tile_buttons[i] != null:
			_style_tile_btn(_tile_buttons[i], i, i == idx)
	_refresh_status()

func _zoom_in() -> void:
	if _grid_canvas.cell_size < 48:
		_grid_canvas.cell_size += 4
		_cell_size_label.text = str(_grid_canvas.cell_size) + "px"
		_grid_canvas.refresh()

func _zoom_out() -> void:
	if _grid_canvas.cell_size > 8:
		_grid_canvas.cell_size -= 4
		_cell_size_label.text = str(_grid_canvas.cell_size) + "px"
		_grid_canvas.refresh()

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_new() -> void:
	_init_grid(DEFAULT_DIM, DEFAULT_DIM)
	level_name  = "my_level"
	level_title = ""
	level_timer = 180
	level_tilt_x = 0
	level_tilt_z = 0
	level_marble_type = "sphere"
	level_marble_size = 1.0
	if _name_edit:  _name_edit.text  = level_name
	if _title_edit: _title_edit.text = level_title
	if _timer_spin: _timer_spin.value = level_timer
	if _tilt_x_spin: _tilt_x_spin.value = level_tilt_x
	if _tilt_z_spin: _tilt_z_spin.value = level_tilt_z
	if _marble_option:    _marble_option.selected = 0
	if _marble_size_spin: _marble_size_spin.value = 1.0
	_sync_canvas()
	_refresh_status()

func _on_save() -> void:
	if not has_start or not has_end:
		_status_label.text = "  ! Cannot save - level needs both a Start (S) and End (G) tile."
		return
	var dir := "user://levels/"
	DirAccess.make_dir_recursive_absolute(dir)
	var safe := level_name.strip_edges().replace(" ", "_")
	if safe.is_empty(): safe = "untitled"
	var path := dir + safe + ".txt"
	_write_level(path)


func _write_level(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_status_label.text = "  ✗ Save failed — cannot write to " + path
		return
	file.store_string(_level_to_string())
	file.close()
	# On web, user:// is backed by IndexedDB and must be explicitly flushed.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("FS.syncfs(false, function(err){});")
	_status_label.text = "  Saved: " + path

func _on_save_stock() -> void:
	if not has_start or not has_end:
		_status_label.text = "  ! Cannot save - level needs both a Start (S) and End (G) tile."
		return
	var safe := level_name.strip_edges().replace(" ", "_")
	if safe.is_empty(): safe = "untitled"
	var path := "res://levels/" + safe + ".txt"
	_write_level(path)

func _on_load() -> void:
	_show_load_overlay()

func _on_play() -> void:
	if not has_start or not has_end:
		_status_label.text = "  ! Cannot test - level needs a Start (S) and End (G) tile."
		return
	GameState.editor_level_content = _level_to_string()
	GameState.editor_level_name = level_name
	GameState.from_editor = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/splash_screen.tscn")

# ── Load overlay ───────────────────────────────────────────────────────────────

func _show_load_overlay() -> void:
	if _load_overlay:
		_load_overlay.queue_free()

	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_bg(overlay, Color(0.06, 0.06, 0.13, 0.96))
	_load_overlay = overlay

	var vbox := VBoxContainer.new()
	overlay.add_child(vbox)

	var title := Label.new(); title.text = "Load Level"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var levels := _collect_levels()
	for lvl in levels:
		var lpath: String    = lvl.path
		var lname: String    = lvl.name
		var ldisplay: String = lvl.display
		var is_custom: bool  = lpath.begins_with("user://")

		var b := Button.new()
		b.text = "  " + ldisplay
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			var f := FileAccess.open(lpath, FileAccess.READ)
			if f:
				var content := f.get_as_text()
				f.close()
				level_name = lname
				if _name_edit: _name_edit.text = level_name
				_load_from_string(content)
			overlay.queue_free()
			_load_overlay = null
		)

		if is_custom or OS.has_feature("editor"):
			var row := HBoxContainer.new()
			row.add_child(b)
			var del := _del_btn()
			del.pressed.connect(func(): _confirm_delete(lpath, ldisplay, overlay))
			row.add_child(del)
			list.add_child(row)
		else:
			list.add_child(b)

	if levels.is_empty():
		var lbl := Label.new(); lbl.text = "No levels found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		list.add_child(lbl)

	var cancel := _btn("Cancel", Color(0.30, 0.20, 0.38))
	cancel.custom_minimum_size = Vector2(180, 44)
	cancel.pressed.connect(func(): overlay.queue_free(); _load_overlay = null)
	vbox.add_child(cancel)

	add_child(overlay)

func _del_btn() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(44, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.07, 0.07)
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.38, 0.12, 0.12)
	b.add_theme_stylebox_override("hover", h)
	return b

func _confirm_delete(path: String, display: String, parent: Control) -> void:
	var confirm := PanelContainer.new()
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_bg(confirm, Color(0.04, 0.04, 0.10, 0.97))

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.anchor_left = 0.5; center.anchor_right  = 0.5
	center.anchor_top  = 0.5; center.anchor_bottom = 0.5
	center.offset_left = -260; center.offset_right  = 260
	center.offset_top  = -100; center.offset_bottom = 100
	confirm.add_child(center)

	var msg := Label.new()
	msg.text = "Delete this level?\n\n" + display + "\n\nThis cannot be undone."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(msg)
	_hspace_v(center, 20)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	var del_btn := _btn("Delete", Color(0.50, 0.12, 0.12))
	del_btn.custom_minimum_size = Vector2(120, 38)
	del_btn.pressed.connect(func():
		DirAccess.remove_absolute(path)
		parent.queue_free()
		_load_overlay = null
		_show_load_overlay()
	)
	row.add_child(del_btn)
	_hspace(row, 16)
	var cancel_btn := _btn("Cancel", Color(0.28, 0.20, 0.38))
	cancel_btn.custom_minimum_size = Vector2(120, 38)
	cancel_btn.pressed.connect(func(): confirm.queue_free())
	row.add_child(cancel_btn)

	parent.add_child(confirm)
	cancel_btn.grab_focus()

func _hspace_v(parent: VBoxContainer, h: int) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _collect_levels() -> Array:
	var out: Array = []
	for pair in [["res://levels/", "[Built-in]  "], ["user://levels/", "[Custom]     "]]:
		var dir: String = pair[0]
		var prefix: String = pair[1]
		var d := DirAccess.open(dir)
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
			var path: String = dir + f
			var display_name: String = _read_level_title(path)
			var label: String = display_name if display_name != "" else f.get_basename()
			out.append({"path": path, "name": f.get_basename(), "display": prefix + label})
	return out

## Peek into a level file and return the !name= value, or "".
func _read_level_title(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("!name="):
			file.close()
			return line.substr(6)
		elif not line.begins_with("!") and line != "":
			break
	file.close()
	return ""
