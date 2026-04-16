extends Control

## 2-D grid drawing and mouse-paint input for the level editor.
## Instantiated at runtime by level_editor.gd.

# Tile indices — kept in sync with level_editor.gd's TileType enum
const TILE_EMPTY       := 0
const TILE_FLOOR       := 1
const TILE_WALL        := 2
const TILE_START       := 3
const TILE_END         := 4
const TILE_MAP         := 5
const TILE_INVIS_WALL  := 6
const TILE_FAKE_WALL   := 7
const TILE_KEY_Y       := 8
const TILE_DOOR_Y      := 9
const TILE_INVIS_FLOOR := 10
const TILE_KEY_G       := 11
const TILE_DOOR_G      := 12
const TILE_KEY_R       := 13
const TILE_DOOR_R      := 14

const TILE_COLORS: Array = [
	Color(0.10, 0.10, 0.13),   # EMPTY
	Color(0.52, 0.56, 0.63),   # FLOOR
	Color(0.20, 0.30, 0.50),   # WALL
	Color(0.15, 0.78, 0.22),   # START
	Color(0.88, 0.73, 0.08),   # END
	Color(0.15, 0.65, 0.72),   # MAP
	Color(0.38, 0.62, 0.88),   # INVIS_WALL
	Color(0.58, 0.30, 0.68),   # FAKE_WALL
	Color(0.92, 0.74, 0.10),   # KEY_Y   — gold
	Color(0.20, 0.38, 0.62),   # DOOR_Y  — dark blue
	Color(0.38, 0.38, 0.38),   # INVIS_FLOOR
	Color(0.18, 0.72, 0.26),   # KEY_G   — green
	Color(0.14, 0.34, 0.20),   # DOOR_G  — dark green
	Color(0.82, 0.18, 0.18),   # KEY_R   — red
	Color(0.36, 0.14, 0.14),   # DOOR_R  — dark red
]

# Tile types treated as solid walls when auto-detecting door direction
const _SOLID_TILES := [2, 6, 7, 9, 12, 14]  # WALL, INVIS_WALL, FAKE_WALL, DOOR_Y/G/R
const GRID_LINE := Color(0.30, 0.30, 0.36, 0.55)
const HOVER_BORDER := Color(1.0, 1.0, 1.0, 0.55)

## Set by level_editor.gd before adding to the scene tree
var grid: Array = []
var grid_rows: int = 20
var grid_cols: int = 20
var cell_size: int = 20
var current_tool: int = TILE_FLOOR
var editor_node: Node = null   # ref to LevelEditor for set_cell()

var _painting: bool = false
var _paint_value: int = TILE_FLOOR
var _hover_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode   = Control.FOCUS_ALL
	_update_size()

func _update_size() -> void:
	custom_minimum_size = Vector2(grid_cols * cell_size, grid_rows * cell_size)

func refresh() -> void:
	_update_size()
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if grid.is_empty():
		return
	var cs := float(cell_size)

	for row in grid_rows:
		for col in grid_cols:
			var tile: int = grid[row][col]
			var rx := col * cs
			var ry := row * cs
			draw_rect(Rect2(rx, ry, cs, cs), TILE_COLORS[tile])
			draw_rect(Rect2(rx, ry, cs, cs), GRID_LINE, false, 1.0)
			# Key symbol on all key and door tiles
			var _is_key  := tile == TILE_KEY_Y  or tile == TILE_KEY_G  or tile == TILE_KEY_R
			var _is_door := tile == TILE_DOOR_Y or tile == TILE_DOOR_G or tile == TILE_DOOR_R
			if (_is_key or _is_door) and cs >= 14.0:
				var font_size := int(cs * 0.55)
				draw_string(ThemeDB.fallback_font, Vector2(rx + cs * 0.18, ry + cs * 0.72),
							"⚿", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
							Color(1.0, 1.0, 1.0, 0.80))

	# Hover highlight
	if _hover_cell.x >= 0 and _hover_cell.y >= 0:
		draw_rect(
			Rect2(_hover_cell.x * cs, _hover_cell.y * cs, cs, cs),
			HOVER_BORDER, false, 2.0
		)

# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting   = mb.pressed
			_paint_value = current_tool
			if mb.pressed:
				_paint_at(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_painting   = mb.pressed
			_paint_value = TILE_EMPTY
			if mb.pressed:
				_paint_at(mb.position)
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var cell := _pos_to_cell(mm.position)
		if cell != _hover_cell:
			_hover_cell = cell
			queue_redraw()
		if _painting:
			_paint_at(mm.position)
		accept_event()

func _pos_to_cell(pos: Vector2) -> Vector2i:
	var col := int(pos.x / cell_size)
	var row := int(pos.y / cell_size)
	if col < 0 or col >= grid_cols or row < 0 or row >= grid_rows:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _paint_at(pos: Vector2) -> void:
	var cell := _pos_to_cell(pos)
	if cell.x < 0:
		return
	if editor_node:
		editor_node.set_cell(cell.y, cell.x, _paint_value)
	queue_redraw()
