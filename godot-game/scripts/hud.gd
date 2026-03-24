# hud.gd
# HUD overlay for Realm of Rivals
# Shows: health bar, stats, event log, relationship panel, faction panel
extends CanvasLayer
class_name GameHUD

# UI Node references (set in _ready)
var health_bar: ProgressBar
var health_label: Label
var stats_label: Label
var event_log: RichTextLabel
var relationship_panel: Panel
var rel_panel_content: RichTextLabel
var rel_panel_toggle: Button
var faction_panel: Panel
var faction_content: RichTextLabel
var faction_toggle: Button
var minimap: Control
var notification_container: VBoxContainer
var turn_label: Label
var controls_label: Label

# State
var relationship_manager: RelationshipManager
var faction_manager: FactionManager
var player: PlayerCharacter
var all_npcs: Array = []

var rel_panel_visible: bool = false
var faction_panel_visible: bool = false

const MAX_LOG_ENTRIES: int = 8

signal action_requested(action: String)

func _ready() -> void:
	_build_hud()

func setup(rel_mgr: RelationshipManager, fac_mgr: FactionManager, p: PlayerCharacter) -> void:
	relationship_manager = rel_mgr
	faction_manager = fac_mgr
	player = p
	_refresh_all()

func set_npcs(npcs: Array) -> void:
	all_npcs = npcs

# --- Build HUD ---

func _build_hud() -> void:
	# Root control
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Top bar (health + stats) ---
	var top_bar := Panel.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.size = Vector2(1280, 56)
	top_bar.position = Vector2(0, 0)
	root.add_child(top_bar)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	top_style.border_color = Color(0.3, 0.3, 0.5)
	top_style.set_border_width_all(1)
	top_bar.add_theme_stylebox_override("panel", top_style)

	# Health bar
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(10, 10)
	health_bar.size = Vector2(200, 20)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	top_bar.add_child(health_bar)

	health_label = Label.new()
	health_label.position = Vector2(10, 32)
	health_label.size = Vector2(200, 18)
	health_label.add_theme_font_size_override("font_size", 11)
	health_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	health_label.text = "HP: 100/100"
	top_bar.add_child(health_label)

	# Stats
	stats_label = Label.new()
	stats_label.position = Vector2(220, 8)
	stats_label.size = Vector2(500, 44)
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	stats_label.text = "ATK:15  DEF:10  CHA:12  Gold:50  Rep:0  Turn:0"
	top_bar.add_child(stats_label)

	# Turn label
	turn_label = Label.new()
	turn_label.position = Vector2(730, 8)
	turn_label.size = Vector2(150, 44)
	turn_label.add_theme_font_size_override("font_size", 11)
	turn_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	turn_label.text = "Turn: 0"
	top_bar.add_child(turn_label)

	# Relationship panel toggle button
	rel_panel_toggle = Button.new()
	rel_panel_toggle.position = Vector2(890, 8)
	rel_panel_toggle.size = Vector2(130, 38)
	rel_panel_toggle.text = "Relations [R]"
	rel_panel_toggle.add_theme_font_size_override("font_size", 11)
	rel_panel_toggle.pressed.connect(_toggle_relationship_panel)
	top_bar.add_child(rel_panel_toggle)

	# Faction panel toggle button
	faction_toggle = Button.new()
	faction_toggle.position = Vector2(1030, 8)
	faction_toggle.size = Vector2(120, 38)
	faction_toggle.text = "Faction [F]"
	faction_toggle.add_theme_font_size_override("font_size", 11)
	faction_toggle.pressed.connect(_toggle_faction_panel)
	top_bar.add_child(faction_toggle)

	# --- Event log (bottom left) ---
	var log_panel := Panel.new()
	log_panel.position = Vector2(0, 660)
	log_panel.size = Vector2(420, 120)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.05, 0.05, 0.08, 0.88)
	log_style.border_color = Color(0.2, 0.3, 0.4)
	log_style.set_border_width_all(1)
	log_panel.add_theme_stylebox_override("panel", log_style)
	root.add_child(log_panel)

	var log_title := Label.new()
	log_title.text = "Event Log"
	log_title.position = Vector2(5, 2)
	log_title.add_theme_font_size_override("font_size", 10)
	log_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	log_panel.add_child(log_title)

	event_log = RichTextLabel.new()
	event_log.position = Vector2(5, 18)
	event_log.size = Vector2(410, 98)
	event_log.bbcode_enabled = true
	event_log.scroll_following = true
	event_log.add_theme_font_size_override("normal_font_size", 10)
	log_panel.add_child(event_log)

	# --- Controls hint (bottom right) ---
	controls_label = Label.new()
	controls_label.position = Vector2(860, 660)
	controls_label.size = Vector2(420, 120)
	controls_label.add_theme_font_size_override("font_size", 10)
	controls_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	controls_label.text = "WASD/Arrows: Move  |  E: Interact  |  R: Relations  |  F: Faction"
	root.add_child(controls_label)

	# --- Notification container (center-top area) ---
	notification_container = VBoxContainer.new()
	notification_container.position = Vector2(440, 65)
	notification_container.size = Vector2(400, 200)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notification_container)

	# --- Relationship panel (right side, toggleable) ---
	relationship_panel = Panel.new()
	relationship_panel.position = Vector2(1050, 60)
	relationship_panel.size = Vector2(230, 580)
	relationship_panel.visible = false
	var rel_style := StyleBoxFlat.new()
	rel_style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	rel_style.border_color = Color(0.3, 0.4, 0.6)
	rel_style.set_border_width_all(2)
	relationship_panel.add_theme_stylebox_override("panel", rel_style)
	root.add_child(relationship_panel)

	var rel_title := Label.new()
	rel_title.text = "⚔ Relationships"
	rel_title.position = Vector2(8, 5)
	rel_title.size = Vector2(214, 20)
	rel_title.add_theme_font_size_override("font_size", 12)
	rel_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	relationship_panel.add_child(rel_title)

	rel_panel_content = RichTextLabel.new()
	rel_panel_content.position = Vector2(5, 28)
	rel_panel_content.size = Vector2(220, 545)
	rel_panel_content.bbcode_enabled = true
	rel_panel_content.add_theme_font_size_override("normal_font_size", 10)
	relationship_panel.add_child(rel_panel_content)

	# --- Faction panel (right side, toggleable) ---
	faction_panel = Panel.new()
	faction_panel.position = Vector2(820, 60)
	faction_panel.size = Vector2(220, 400)
	faction_panel.visible = false
	var fac_style := StyleBoxFlat.new()
	fac_style.bg_color = Color(0.06, 0.08, 0.06, 0.95)
	fac_style.border_color = Color(0.3, 0.5, 0.3)
	fac_style.set_border_width_all(2)
	faction_panel.add_theme_stylebox_override("panel", fac_style)
	root.add_child(faction_panel)

	var fac_title := Label.new()
	fac_title.text = "🏰 Faction"
	fac_title.position = Vector2(8, 5)
	fac_title.size = Vector2(204, 20)
	fac_title.add_theme_font_size_override("font_size", 12)
	fac_title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	faction_panel.add_child(fac_title)

	faction_content = RichTextLabel.new()
	faction_content.position = Vector2(5, 28)
	faction_content.size = Vector2(210, 365)
	faction_content.bbcode_enabled = true
	faction_content.add_theme_font_size_override("normal_font_size", 10)
	faction_panel.add_child(faction_content)

# --- Update methods ---

func update_player_stats(p: PlayerCharacter) -> void:
	if p == null:
		return
	health_bar.max_value = p.max_hp
	health_bar.value = p.hp
	# Color bar based on HP %
	var hp_ratio: float = float(p.hp) / float(p.max_hp)
	if hp_ratio > 0.6:
		health_bar.modulate = Color(0.3, 0.9, 0.3)
	elif hp_ratio > 0.3:
		health_bar.modulate = Color(0.9, 0.7, 0.1)
	else:
		health_bar.modulate = Color(0.9, 0.2, 0.2)

	health_label.text = "HP: %d/%d" % [p.hp, p.max_hp]
	stats_label.text = "ATK:%d  DEF:%d  CHA:%d  Gold:%d  Rep:%d" % [
		p.attack, p.defense, p.charisma, p.gold, p.reputation
	]
	turn_label.text = "Turn: %d" % p.turn_count

func add_log_entry(text: String, color: Color = Color.WHITE) -> void:
	var hex: String = color.to_html(false)
	event_log.append_text("[color=#%s]%s[/color]\n" % [hex, text])

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate.a = 1.0
	notification_container.add_child(lbl)

	# Auto-fade and remove
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 3.0).set_delay(1.5)
	tween.tween_callback(lbl.queue_free)

# --- Relationship panel ---

func _toggle_relationship_panel() -> void:
	rel_panel_visible = not rel_panel_visible
	relationship_panel.visible = rel_panel_visible
	if rel_panel_visible:
		_refresh_relationship_panel()

func _refresh_relationship_panel() -> void:
	if relationship_manager == null or player == null:
		return
	rel_panel_content.clear()

	var rels: Array = relationship_manager.get_relationships_for(player.character)
	if rels.is_empty():
		rel_panel_content.append_text("[color=#888888]No known relationships[/color]")
		return

	# Sort by intensity
	rels.sort_custom(func(a, b): return a.intensity < b.intensity)

	for rel in rels:
		var other: Character = rel.get_other(player.character)
		var rel_type: int = rel.get_perspective(player.character)
		var color_hex: String = _rel_color(rel_type).to_html(false)
		var type_name: String = _rel_name(rel_type)
		var intensity: int = rel.intensity
		var bar: String = _make_intensity_bar(intensity)

		rel_panel_content.append_text(
			"[color=#%s]%s[/color]\n" % [color_hex, other.name] +
			"[color=#%s]  %s (Int: %d)[/color]\n" % [color_hex, type_name, intensity] +
			"  [color=#555555]%s[/color]\n\n" % bar
		)

# --- Faction panel ---

func _toggle_faction_panel() -> void:
	faction_panel_visible = not faction_panel_visible
	faction_panel.visible = faction_panel_visible
	if faction_panel_visible:
		_refresh_faction_panel()

func _refresh_faction_panel() -> void:
	if faction_manager == null:
		return
	faction_content.clear()

	# Party members
	faction_content.append_text("[color=#88ff88]Party (%d/4):[/color]\n" % faction_manager.party_members.size())
	if faction_manager.party_members.is_empty():
		faction_content.append_text("[color=#666666]  (empty)[/color]\n")
	else:
		for char_id in faction_manager.party_members:
			var npc = _find_npc_by_id(char_id)
			if npc:
				faction_content.append_text(
					"  [color=#aaffaa]%s[/color] [color=#666666](%s)[/color]\n" % [
						npc.character.name, NPCCharacter.ROLE_NAMES.get(npc.npc_role, "?")
					]
				)

	# Morale
	var morale_color: String = "88ff88" if faction_manager.party_morale >= 60 else ("ffaa44" if faction_manager.party_morale >= 30 else "ff4444")
	faction_content.append_text(
		"\n[color=#aaaaaa]Morale:[/color] [color=#%s]%d%%[/color]\n\n" % [
			morale_color, faction_manager.party_morale
		]
	)

	# Faction standings
	faction_content.append_text("[color=#aaaaaa]Faction Standings:[/color]\n")
	for faction_type in FactionManager.FactionType.values():
		if faction_type == FactionManager.FactionType.PLAYER_FACTION:
			continue
		var rep: int = faction_manager.get_faction_reputation(faction_type)
		var status: String = faction_manager.get_faction_status(faction_type)
		var name: String = faction_manager.get_faction_name(faction_type)
		var rep_color: String = "88ff88" if rep >= 0 else "ff6644"
		faction_content.append_text(
			"  [color=#cccccc]%s[/color]: [color=#%s]%s[/color]\n" % [name, rep_color, status]
		)

func _find_npc_by_id(char_id: String) -> NPCCharacter:
	for npc in all_npcs:
		if npc is NPCCharacter and npc.character and npc.character.id == char_id:
			return npc
	return null

# --- Refresh all panels ---

func _refresh_all() -> void:
	if player:
		update_player_stats(player)
	if rel_panel_visible:
		_refresh_relationship_panel()
	if faction_panel_visible:
		_refresh_faction_panel()

# --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_toggle_relationship_panel()
		elif event.keycode == KEY_F:
			_toggle_faction_panel()

# --- Helpers ---

func _rel_name(rel_type: int) -> String:
	match rel_type:
		RelationshipType.Type.NEMESIS:  return "NEMESIS"
		RelationshipType.Type.RIVAL:    return "Rival"
		RelationshipType.Type.BETRAYER: return "Betrayer"
		RelationshipType.Type.NEUTRAL:  return "Neutral"
		RelationshipType.Type.FRIEND:   return "Friend"
		RelationshipType.Type.ALLY:     return "Ally"
		RelationshipType.Type.MENTOR:   return "Mentor"
	return "Unknown"

func _rel_color(rel_type: int) -> Color:
	match rel_type:
		RelationshipType.Type.NEMESIS:  return Color(0.9, 0.1, 0.1)
		RelationshipType.Type.RIVAL:    return Color(0.9, 0.45, 0.1)
		RelationshipType.Type.BETRAYER: return Color(0.8, 0.1, 0.6)
		RelationshipType.Type.NEUTRAL:  return Color(0.8, 0.8, 0.2)
		RelationshipType.Type.FRIEND:   return Color(0.3, 0.85, 0.3)
		RelationshipType.Type.ALLY:     return Color(0.1, 0.9, 0.5)
		RelationshipType.Type.MENTOR:   return Color(0.5, 0.7, 1.0)
	return Color.WHITE

func _make_intensity_bar(intensity: int) -> String:
	# Intensity is clamped to [-100, 100] by RelationshipManager
	var bar_len: int = 10
	var clamped: int = clampi(intensity, -100, 100)
	var filled: int = int((clamped + 100) / 20.0)  # maps -100..100 -> 0..10
	filled = clampi(filled, 0, bar_len)
	return "[" + "█".repeat(filled) + "░".repeat(bar_len - filled) + "] %d" % intensity
