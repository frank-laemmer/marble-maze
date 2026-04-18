GODOT ?= godot

# Run all render scenes in sequence
.PHONY: renders icon header screenshots

renders: icon header screenshots

icon:
	$(GODOT) "$(CURDIR)/scenes/icon_render.tscn"

header:
	$(GODOT) "$(CURDIR)/scenes/header_render.tscn"

screenshots:
	$(GODOT) "$(CURDIR)/scenes/screenshot_render.tscn"
