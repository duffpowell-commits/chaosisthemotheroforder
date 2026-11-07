extends Node
## Autoload. The default font has no ♥ ● ◎ ✕. On desktop Godot borrows them
## from system fonts; a browser has none, so they showed as boxes in the web
## build (J1 spike). Ship a small DejaVu subset as the fallback everywhere.

const SYMBOLS := preload("res://assets/fonts/symbols_dejavu.ttf")


func _enter_tree() -> void:
	var f: Font = ThemeDB.fallback_font
	if f != null and not f.fallbacks.has(SYMBOLS):
		var fb := f.fallbacks.duplicate()
		fb.append(SYMBOLS)
		f.fallbacks = fb
