extends Control

## Draws a top-down minimap of the current level.
## By default walls and floors share the same colour, making the maze shape
## look like a uniform blob. When the marble stands on an 'M' (Map) tile,
## walls are drawn in their distinct colour so the layout becomes readable.

const CELL: float = 4.0  # must match LevelLoader.CELL

const COLOR_FLOOR       := Color(0.52, 0.55, 0.62, 0.9)
const COLOR_INVIS_FLOOR := Color(0.38, 0.38, 0.38, 0.9)   # darker grey — revealed only on Map tile
const COLOR_WALL        := Color(0.38, 0.38, 0.38, 0.95)  # revealed only on Map tile
const COLOR_INVIS_WALL  := Color(0.40, 0.68, 0.96, 0.95)  # bright blue — revealed only on Map tile
const COLOR_FAKE_WALL   := Color(0.55, 0.35, 0.70, 0.95)  # purple — revealed only on Map tile
const COLOR_MAP         := Color(0.15, 0.65, 0.72, 1.0)   # cyan — always visible
const COLOR_START       := Color(0.2,  1.0,  0.4,  1.0)
const COLOR_GOAL        := Color(1.0,  0.8,  0.1,  1.0)

var _marble: Node3D

func _ready() -> void:
	_marble = get_tree().get_first_node_in_group("marble")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if LevelLoader.grid.is_empty():
		return

	var rows := LevelLoader.grid_rows
	var cols := LevelLoader.grid_cols
	if rows == 0 or cols == 0:
		return

	var w := size.x
	var h := size.y
	var margin := 8.0
	var cell_px := minf((w - margin * 2.0) / float(cols),
	                    (h - margin * 2.0) / float(rows))
	var map_w := cell_px * float(cols)
	var map_h := cell_px * float(rows)
	var ox := (w - map_w) * 0.5
	var oy := (h - map_h) * 0.5

	# ── Check whether the marble is on a Map tile ─────────────────────────────
	var show_walls := false
	if _marble:
		var mp := _marble.global_position
		var mc := int(mp.x / CELL)
		var mr := int(mp.z / CELL)
		if mr >= 0 and mr < rows and mc >= 0 and mc < cols:
			show_walls = (LevelLoader.grid[mr][mc] == "M")

	# ── Grid cells ────────────────────────────────────────────────────────────
	for ri in rows:
		for ci in cols:
			var ch: String = LevelLoader.grid[ri][ci]
			if ch == "_":
				continue  # empty — nothing drawn, shows blurred background
			if ch == "V" and not show_walls:
				continue  # invisible floor — hidden until marble is on a Map tile
			var col: Color
			if ch == "#":
				# Wall: distinct colour only when map is revealed, otherwise
				# drawn as floor so the shape is a uniform unreadable blob.
				col = COLOR_WALL if show_walls else COLOR_FLOOR
			elif ch == "I":
				# Invisible wall: shown in bright blue on map, hidden otherwise.
				col = COLOR_INVIS_WALL if show_walls else COLOR_FLOOR
			elif ch == "F":
				# Fake wall: shown in purple on map, hidden otherwise.
				col = COLOR_FAKE_WALL if show_walls else COLOR_FLOOR
			elif ch == "V":
				col = COLOR_INVIS_FLOOR  # only reached when show_walls is true
			elif ch == "M":
				col = COLOR_MAP
			else:
				# floor / S / G — plain floor; start and goal drawn on top below.
				col = COLOR_FLOOR
			draw_rect(
				Rect2(ox + float(ci) * cell_px, oy + float(ri) * cell_px,
				      cell_px - 1.0, cell_px - 1.0),
				col)

	# ── Start — green square (drawn on top of the floor colour) ───────────────
	var sc := LevelLoader.start_cell
	draw_rect(Rect2(ox + float(sc.x) * cell_px + 1.0,
	               oy + float(sc.y) * cell_px + 1.0,
	               cell_px - 3.0, cell_px - 3.0),
	          COLOR_START)

	# ── Goal — gold square ────────────────────────────────────────────────────
	var gc := LevelLoader.goal_cell
	draw_rect(Rect2(ox + float(gc.x) * cell_px + 1.0,
	               oy + float(gc.y) * cell_px + 1.0,
	               cell_px - 3.0, cell_px - 3.0),
	          COLOR_GOAL)

	# ── Marble — bright yellow dot with dark outline ──────────────────────────
	if _marble:
		var mp := _marble.global_position
		var mx := ox + (mp.x / CELL) * cell_px
		var my := oy + (mp.z / CELL) * cell_px
		var r  := maxf(cell_px * 0.40, 3.5)
		draw_circle(Vector2(mx, my), r + 1.5, Color(0.0, 0.0, 0.0, 0.85))
		draw_circle(Vector2(mx, my), r,       Color(1.0, 0.95, 0.25, 1.0))

	# ── Panel border ──────────────────────────────────────────────────────────
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.4, 0.5, 0.75, 0.6), false, 1.5)
