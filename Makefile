GODOT ?= godot

# Run all render scenes in sequence
.PHONY: renders icon header screenshots cover splash

renders: icon header cover splash screenshots

icon:
	$(GODOT) "$(CURDIR)/scenes/icon_render.tscn"

header:
	$(GODOT) "$(CURDIR)/scenes/header_render.tscn"

cover:
	$(GODOT) "$(CURDIR)/scenes/cover_render.tscn"

splash:
	$(GODOT) "$(CURDIR)/scenes/splash_render.tscn"

screenshots:
	$(GODOT) "$(CURDIR)/scenes/screenshot_render.tscn"
