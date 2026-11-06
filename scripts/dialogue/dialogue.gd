extends RefCounted
## A small dialogue runner for plain-text script files (docs/slice-spec.md §12).
## Phone-editable: no plugins, no C#. Format:
##
##   # comment
##   == node_name                 starts a node
##   TEODOR: Words.               a line (speaker in capitals)
##   > He doesn't look up.        narration (no speaker)
##   * Choice text -> target      a choice; consecutive * lines form one menu
##   * [if expr] Choice -> target a choice shown only when expr is true
##   if expr -> target            jump when expr is true
##   set key = expr               store a value in the runner's vars
##   -> target                    jump (-> END stops)
##
## A node that runs out of lines ends the scene. Expressions are Godot
## Expressions over the context dictionary plus anything already set.

const END := "END"


## Parses script text into {node_name: [ops]}. Bad lines become "error" ops so
## lint() can report them with line numbers.
static func parse(text: String) -> Dictionary:
	var nodes := {}
	var current: Array = []
	var current_name := ""
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			current_name = line.substr(2).strip_edges()
			if nodes.has(current_name):
				current = nodes[current_name]
				current.append({"op": "error", "line": n, "msg": "duplicate node " + current_name})
			else:
				current = []
				nodes[current_name] = current
			continue
		if current_name == "":
			nodes["__orphan"] = nodes.get("__orphan", [])
			nodes["__orphan"].append({"op": "error", "line": n, "msg": "line outside any node"})
			continue
		var op = _parse_line(line, n, current)
		if op != null:  # null: the choice was merged into the previous menu
			current.append(op)
	return nodes


static func _parse_line(line: String, n: int, current: Array):
	if line.begins_with("->"):
		return {"op": "goto", "target": line.substr(2).strip_edges(), "line": n}
	if line.begins_with(">"):
		return {"op": "line", "speaker": "", "text": line.substr(1).strip_edges(), "line": n}
	if line.begins_with("*"):
		var body := line.substr(1).strip_edges()
		var cond := ""
		if body.begins_with("[if "):
			var close := body.find("]")
			if close < 0:
				return {"op": "error", "line": n, "msg": "unclosed [if ...]"}
			cond = body.substr(4, close - 4).strip_edges()
			body = body.substr(close + 1).strip_edges()
		var arrow := body.rfind("->")
		if arrow < 0:
			return {"op": "error", "line": n, "msg": "choice needs -> target"}
		var option := {"text": body.substr(0, arrow).strip_edges(), "cond": cond,
			"target": body.substr(arrow + 2).strip_edges(), "line": n}
		if not current.is_empty() and current[-1].op == "menu":
			current[-1].options.append(option)
			return null
		return {"op": "menu", "options": [option], "line": n}
	if line.begins_with("if "):
		var arrow := line.rfind("->")
		if arrow < 0:
			return {"op": "error", "line": n, "msg": "if needs -> target"}
		return {"op": "if", "cond": line.substr(3, arrow - 3).strip_edges(),
			"target": line.substr(arrow + 2).strip_edges(), "line": n}
	if line.begins_with("set "):
		var eq := line.find("=")
		if eq < 0:
			return {"op": "error", "line": n, "msg": "set needs key = value"}
		return {"op": "set", "key": line.substr(4, eq - 4).strip_edges(),
			"expr": line.substr(eq + 1).strip_edges(), "line": n}
	var colon := line.find(":")
	if colon > 0:
		var speaker := line.substr(0, colon).strip_edges()
		if speaker == speaker.to_upper() and speaker.to_upper() != speaker.to_lower():
			return {"op": "line", "speaker": speaker, "text": line.substr(colon + 1).strip_edges(), "line": n}
	return {"op": "error", "line": n, "msg": "can't read: " + line}


## Returns a list of problems: bad lines, missing jump targets, broken expressions.
## `ctx_keys` are the names expressions may use besides set vars.
static func lint(nodes: Dictionary, ctx_keys: Array = []) -> Array[String]:
	var out: Array[String] = []
	var set_keys := []
	for k in nodes:
		for o in nodes[k]:
			if o.op == "set":
				set_keys.append(o.key)
	var names: PackedStringArray = PackedStringArray(ctx_keys + set_keys)
	for k in nodes:
		for o in nodes[k]:
			match o.op:
				"error":
					out.append("line %d: %s" % [o.line, o.msg])
				"goto", "if":
					if o.target != END and not nodes.has(o.target):
						out.append("line %d: no node '%s'" % [o.line, o.target])
				"menu":
					for c in o.options:
						if c.target != END and not nodes.has(c.target):
							out.append("line %d: no node '%s'" % [c.line, c.target])
			for expr in [o.get("cond", ""), o.get("expr", "")] + o.get("options", []).map(func(c): return c.cond):
				if expr != "" and not ctx_keys.is_empty():
					var e := Expression.new()
					if e.parse(expr, names) != OK:
						out.append("line %d: bad expression '%s'" % [o.line, expr])
	return out


## Steps through one scene. Call next() until it returns {"type": "end"}.
## On {"type": "choices"}, call choose(index) before next().
class Runner extends RefCounted:
	var nodes: Dictionary
	var ctx: Dictionary
	var vars := {}
	var _ops: Array = []
	var _pc := 0
	var _menu: Array = []

	func _init(p_nodes: Dictionary, p_ctx: Dictionary) -> void:
		nodes = p_nodes
		ctx = p_ctx

	func start(node: String) -> void:
		_jump(node)

	func next() -> Dictionary:
		var guard := 0
		while guard < 1000:
			guard += 1
			if not _menu.is_empty():
				return {"type": "choices", "options": _menu}
			if _pc >= _ops.size():
				return {"type": "end"}
			var o: Dictionary = _ops[_pc]
			_pc += 1
			match o.op:
				"line":
					return {"type": "line", "speaker": o.speaker, "text": o.text}
				"goto":
					_jump(o.target)
				"if":
					if _truthy(o.cond):
						_jump(o.target)
				"set":
					vars[o.key] = _eval(o.expr)
				"menu":
					var shown := []
					for i in range(o.options.size()):
						var c: Dictionary = o.options[i]
						if c.cond == "" or _truthy(c.cond):
							shown.append({"text": c.text, "index": i, "target": c.target})
					if shown.is_empty():
						continue
					_menu = shown
		push_error("dialogue: runaway loop")
		return {"type": "end"}

	## `index` is the option's "index" field (its position in the script).
	func choose(index: int) -> void:
		for c in _menu:
			if c.index == index:
				_menu = []
				_jump(c.target)
				return
		push_error("dialogue: no visible choice %d" % index)

	func _jump(node: String) -> void:
		_menu = []
		_pc = 0
		_ops = [] if node == END else nodes.get(node, [])
		if node != END and not nodes.has(node):
			push_error("dialogue: no node " + node)

	func _scope() -> Dictionary:
		var d := ctx.duplicate()
		d.merge(vars, true)
		return d

	func _eval(expr: String):
		var scope := _scope()
		var e := Expression.new()
		if e.parse(expr, PackedStringArray(scope.keys())) != OK:
			push_error("dialogue: can't parse '%s': %s" % [expr, e.get_error_text()])
			return null
		var v = e.execute(scope.values(), null, false)
		if e.has_execute_failed():
			push_error("dialogue: '%s' failed: %s" % [expr, e.get_error_text()])
			return null
		return v

	func _truthy(expr: String) -> bool:
		var v = _eval(expr)
		return v != null and bool(v)
