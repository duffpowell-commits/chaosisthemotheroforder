extends RefCounted
## REPORT A BUG (QoL step 3, Nov 25; from godot-game-starter's, in the dossier look): a note,
## then SEND (opens a prefilled GitHub issue; Duff is signed in to the GitHub app) or COPY
## (clipboard, to paste in a text). Adds what a tester can't be asked to type: version, build,
## phone, screen, settings, and the current scene's `bug_state() -> String`.
##   BugReport.open(parent)

const Config = preload("res://scripts/config.gd")
const Sheet = preload("res://scripts/ui/settings_sheet.gd")


static func report_text(note: String, tree: SceneTree) -> String:
	var scene := tree.current_scene
	var state := ""
	if scene != null and scene.has_method("bug_state"):
		state = str(scene.bug_state())
	var lines := [
		note.strip_edges() if note.strip_edges() != "" else "(no note)",
		"",
		"---",
		"game: %s %s" % [Config.game_title(), Config.version_label()],
		"build: %s" % Config.build_info(),
		"device: %s %s | %s | screen %s" % [OS.get_name(), OS.get_version(), OS.get_model_name(),
			str(DisplayServer.screen_get_size())],
		"scene: %s" % (scene.scene_file_path if scene != null else "?"),
		"fps: %d" % Engine.get_frames_per_second(),
	]
	var st: Node = tree.root.get_node_or_null("Settings")
	if st != null:
		lines.append("settings: text %s, graphics %s" % [st.text_name(),
			"LOW" if st.get_value("low_graphics") else "HIGH"])
	if state != "":
		lines.append("state: " + state)
	return "\n".join(lines)


static func issue_url(text: String) -> String:
	var title := text.split("\n")[0].left(60)
	return "https://github.com/%s/issues/new?labels=bug&title=%s&body=%s" % [
		Config.repo(), ("Bug: " + title).uri_encode(), text.uri_encode()]


static func open(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 31
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	# Top half of the screen: the phone keyboard comes up over the bottom half.
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_top", 24)
	holder.add_theme_constant_override("margin_left", 220)
	holder.add_theme_constant_override("margin_right", 220)
	layer.add_child(holder)
	var card := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/dossier/card.png")
	sb.set_texture_margin_all(26)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 26
	sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Sheet._text("REPORT A BUG", 32, Sheet.C_STAMP)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Sheet._text(Config.version_label(), 20, Sheet.C_INK_SOFT))
	col.add_child(Sheet._text("What went wrong? Phone and game details are added for you.", 20, Sheet.C_INK_SOFT))
	var note := TextEdit.new()
	note.name = "note"
	note.custom_minimum_size = Vector2(0, 150)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.placeholder_text = "I tapped... and then..."
	note.add_theme_font_size_override("font_size", 22)
	col.add_child(note)
	var status := Sheet._text("", 20, Sheet.C_INK_SOFT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var send := Sheet._button("SEND (GITHUB)", func():
		OS.shell_open(issue_url(report_text(note.text, parent.get_tree())))
		layer.queue_free())
	send.name = "send"
	row.add_child(send)
	var copy := Sheet._button("COPY", func():
		DisplayServer.clipboard_set(report_text(note.text, parent.get_tree()))
		status.text = "Copied. Paste it in a text.")
	copy.name = "copy"
	row.add_child(copy)
	var close := Sheet._button("CLOSE", func(): layer.queue_free())
	close.name = "close"
	row.add_child(close)
	col.add_child(status)
	note.grab_focus.call_deferred()
	return layer
