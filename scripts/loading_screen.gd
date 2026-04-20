extends Control

const NEXT_SCENE := "res://scenes/ui/splash_screen.tscn"
const MIN_DISPLAY_TIME := 0.6

var _elapsed: float = 0.0
var _load_done: bool = false
var _transitioning: bool = false
var _fade: ColorRect = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.09)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var tex: Texture2D = load("res://assets/splash.png")
	if tex:
		var img_rect := TextureRect.new()
		img_rect.texture = tex
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(img_rect)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_fade)

	ResourceLoader.load_threaded_request(NEXT_SCENE)

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.4)

func _process(delta: float) -> void:
	_elapsed += delta

	if not _load_done:
		var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_load_done = true

	if _load_done and _elapsed >= MIN_DISPLAY_TIME and not _transitioning:
		_transitioning = true
		set_process(false)
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 1.0, 0.3)
		tween.tween_callback(func():
			var packed := ResourceLoader.load_threaded_get(NEXT_SCENE) as PackedScene
			get_tree().change_scene_to_packed(packed))
