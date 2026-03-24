# main.gd
# Root game controller for "Realm of Rivals"
# Manages game states, spawns systems, connects signals
extends Node2D
class_name GameMain

# --- Game States ---
enum GameState {
	MAIN_MENU,
	EXPLORING,
	DIALOGUE,
	COMBAT,
	POST_COMBAT,
	GAME_OVER
}

var current_state: int = GameState.MAIN_MENU

# --- Core systems ---
var relationship_manager: RelationshipManager
var faction_manager: FactionManager
var legacy_manager: LegacyManager
var combat_manager: CombatManager
var dialogue_manager: DialogueManager

# --- Scene nodes ---
var map_node: MapGenerator
var player_node: PlayerCharacter
var hud_node: GameHUD
var npcs: Array = []
var rng: RandomNumberGenerator

# --- UI overlays (built programmatically) ---
var main_menu_panel: Panel
var dialogue_panel: Panel
var combat_panel: Panel
var post_combat_panel: Panel
var game_over_panel: Panel
var camera: Camera2D

# Pending NPC for interaction
var pending_npc: NPCCharacter = null

# --- Initialization ---

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	_init_systems()
	_build_camera()
	_show_main_menu()

func _init_systems() -> void:
	relationship_manager = RelationshipManager.new()
	add_child(relationship_manager)

	faction_manager = FactionManager.new()
	faction_manager.set_relationship_manager(relationship_manager)
	add_child(faction_manager)

	legacy_manager = LegacyManager.new()
	add_child(legacy_manager)

	combat_manager = CombatManager.new()
	add_child(combat_manager)

	dialogue_manager = DialogueManager.new()
	add_child(dialogue_manager)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)

# --- Main Menu ---

func _show_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	_hide_all_overlays()

	if main_menu_panel == null:
		main_menu_panel = _build_main_menu()
		var menu_layer := CanvasLayer.new()
		menu_layer.layer = 10
		add_child(menu_layer)
		menu_layer.add_child(main_menu_panel)

	main_menu_panel.visible = true

func _build_main_menu() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.10)
	panel.add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = "REALM OF RIVALS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	title.position = Vector2(640 - 300, 140)
	title.size = Vector2(600, 60)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Strategy/Roguelike of Shifting Alliances"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	subtitle.position = Vector2(640 - 250, 205)
	subtitle.size = Vector2(500, 28)
	panel.add_child(subtitle)

	var run_count: int = legacy_manager.get_run_count() if legacy_manager else 0
	var nemesis_count: int = legacy_manager.get_nemesis_count() if legacy_manager else 0

	if run_count > 0:
		var legacy_label := Label.new()
		legacy_label.text = "Run #%d | Legacy Nemeses: %d | Total Reputation: %d" % [
			run_count + 1, nemesis_count, legacy_manager.get_total_reputation()
		]
		legacy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legacy_label.add_theme_font_size_override("font_size", 13)
		legacy_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		legacy_label.position = Vector2(640 - 250, 245)
		legacy_label.size = Vector2(500, 22)
		panel.add_child(legacy_label)

	var btn_new := Button.new()
	btn_new.text = "New Game"
	btn_new.position = Vector2(640 - 100, 310)
	btn_new.size = Vector2(200, 50)
	btn_new.add_theme_font_size_override("font_size", 18)
	btn_new.pressed.connect(start_new_game)
	panel.add_child(btn_new)

	var legacy_nemeses = legacy_manager.get_legacy_nemeses()
	if legacy_nemeses.size() > 0:
		var names = legacy_nemeses.map(func(n): return n.get("name", "?"))
		var nemesis_info := Label.new()
		nemesis_info.text = "Your nemeses await: " + ", ".join(names)
		nemesis_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nemesis_info.add_theme_font_size_override("font_size", 12)
		nemesis_info.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		nemesis_info.position = Vector2(640 - 300, 380)
		nemesis_info.size = Vector2(600, 22)
		panel.add_child(nemesis_info)

	var btn_reset := Button.new()
	btn_reset.text = "Reset Legacy"
	btn_reset.position = Vector2(640 - 60, 430)
	btn_reset.size = Vector2(120, 32)
	btn_reset.add_theme_font_size_override("font_size", 11)
	btn_reset.pressed.connect(func(): legacy_manager.reset_legacy(); _show_main_menu())
	panel.add_child(btn_reset)

	var desc := Label.new()
	desc.text = (
		"Explore procedurally generated lands. Every NPC remembers your actions.\n" +
		"Betray an ally? They become a rival. Help a stranger? They become a friend.\n" +
		"Die, and your nemeses carry forward — stronger and angrier."
	)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc.position = Vector2(640 - 350, 490)
	desc.size = Vector2(700, 60)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(desc)

	return panel

# --- New Game ---

func start_new_game() -> void:
	_hide_all_overlays()
	if main_menu_panel != null:
		main_menu_panel.visible = false
	_clear_world()
	_setup_world()
	current_state = GameState.EXPLORING

func _clear_world() -> void:
	if map_node:
		map_node.queue_free()
		map_node = null
	if player_node:
		player_node.queue_free()
		player_node = null
	if hud_node:
		hud_node.queue_free()
		hud_node = null
	for npc in npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	npcs = []
	relationship_manager._characters = {}
	relationship_manager._relationships = {}
	faction_manager.party_members = []
	# Remove old UILayer if present
	var old_ui = get_node_or_null("UILayer")
	if old_ui:
		old_ui.queue_free()

func _setup_world() -> void:
	# 1. Generate map
	map_node = MapGenerator.new()
	add_child(map_node)
	map_node.rng = rng
	map_node.generate(rng.randi())

	# 2. Create player
	_spawn_player(map_node.player_spawn)

	# 3. Spawn NPCs
	_spawn_npcs(map_node.npc_spawn_points.duplicate())

	# 4. Set up HUD
	_setup_hud()

	# 5. Position camera on player
	camera.position = player_node.position

	# 6. Connect relationship callback
	relationship_manager.get_event_system().add_callback(
		func(rel: Relationship, evt: RelationshipEvent) -> void:
			_on_relationship_changed(rel, evt)
	)

func _spawn_player(spawn_tile: Vector2i) -> void:
	var player_char := Character.new(
		"player_0",
		"The Wanderer",
		CharacterType.Type.PLAYER
	)
	relationship_manager.add_character(player_char)

	player_node = PlayerCharacter.new()
	add_child(player_node)
	player_node.setup(player_char, spawn_tile, map_node)
	player_node.player_moved.connect(_on_player_moved)
	player_node.player_stats_changed.connect(_on_player_stats_changed)
	player_node.player_died.connect(_on_player_died)
	player_node.adjacent_to_npc.connect(_on_adjacent_to_npc)

func _spawn_npcs(spawn_points: Array) -> void:
	var roles: Array = [
		NPCCharacter.Role.WARRIOR, NPCCharacter.Role.MERCHANT, NPCCharacter.Role.SCHOLAR,
		NPCCharacter.Role.ASSASSIN, NPCCharacter.Role.LEADER, NPCCharacter.Role.HEALER,
		NPCCharacter.Role.SCOUT, NPCCharacter.Role.BANDIT
	]
	var names: Array = NameGenerator.generate_unique_names(
		spawn_points.size() + 5, rng
	)
	var name_idx: int = 0

	# Spawn legacy nemeses first
	var legacy_nemeses: Array = legacy_manager.get_legacy_nemeses()
	for nemesis_data in legacy_nemeses:
		if spawn_points.is_empty():
			break
		var sp: Dictionary = spawn_points.pop_front()
		var npc_char := Character.new(
			nemesis_data.get("id", "n_legacy_%d" % name_idx),
			nemesis_data.get("name", "Nemesis"),
			CharacterType.Type.VILLAIN
		)
		relationship_manager.add_character(npc_char)
		relationship_manager.create_relationship(
			player_node.character, npc_char,
			RelationshipType.Type.NEMESIS, RelationshipType.Type.NEMESIS,
			nemesis_data.get("intensity", -80)
		)
		var npc := NPCCharacter.new()
		add_child(npc)
		var role_int: int = _role_from_string(nemesis_data.get("role", "Warrior"))
		npc.setup(npc_char, role_int, sp["pos"],
				  90 + nemesis_data.get("bonus_defense", 0),
				  15 + nemesis_data.get("bonus_attack", 0), 10)
		npc.apply_legacy_bonus(
			nemesis_data.get("bonus_attack", 0),
			nemesis_data.get("bonus_defense", 0)
		)
		npc.update_name_label()
		npc.npc_defeated.connect(_on_npc_defeated)
		npcs.append(npc)
		name_idx += 1

	# Spawn regular NPCs
	var max_npcs: int = mini(spawn_points.size(), 10)
	for i in range(max_npcs):
		var sp: Dictionary = spawn_points[i]
		var char_id: String = "npc_%d" % i
		var char_name: String = names[name_idx] if name_idx < names.size() else ("NPC_%d" % i)
		name_idx += 1

		var char_type: int = CharacterType.Type.NPC
		var role: int = roles[rng.randi() % roles.size()]
		if role == NPCCharacter.Role.LEADER:
			char_type = CharacterType.Type.ALLY
		elif role == NPCCharacter.Role.BANDIT:
			char_type = CharacterType.Type.VILLAIN

		var npc_char := Character.new(char_id, char_name, char_type)
		relationship_manager.add_character(npc_char)

		var initial_type_player: int = RelationshipType.Type.NEUTRAL
		var initial_type_npc: int = RelationshipType.Type.NEUTRAL
		var initial_intensity: int = 0
		match rng.randi() % 10:
			0:
				initial_type_player = RelationshipType.Type.FRIEND
				initial_type_npc = RelationshipType.Type.FRIEND
				initial_intensity = 30
			1:
				initial_type_player = RelationshipType.Type.RIVAL
				initial_type_npc = RelationshipType.Type.RIVAL
				initial_intensity = -25

		relationship_manager.create_relationship(
			player_node.character, npc_char,
			initial_type_player, initial_type_npc, initial_intensity
		)

		# NPC-to-NPC relationships
		if npcs.size() > 0 and rng.randi() % 3 == 0:
			var other_npc: NPCCharacter = npcs[rng.randi() % npcs.size()]
			if other_npc.character.id != npc_char.id:
				var npc_rel_type: int = RelationshipType.Type.NEUTRAL
				if rng.randi() % 4 == 0:
					npc_rel_type = RelationshipType.Type.RIVAL
				elif rng.randi() % 5 == 0:
					npc_rel_type = RelationshipType.Type.FRIEND
				relationship_manager.create_relationship(
					npc_char, other_npc.character, npc_rel_type, npc_rel_type, 0
				)

		var npc := NPCCharacter.new()
		add_child(npc)
		npc.setup(npc_char, role, sp["pos"],
				  70 + rng.randi() % 30,
				  8 + rng.randi() % 10,
				  5 + rng.randi() % 8)
		npc.update_name_label()
		npc.npc_defeated.connect(_on_npc_defeated)
		npcs.append(npc)

func _setup_hud() -> void:
	hud_node = GameHUD.new()
	add_child(hud_node)
	hud_node.setup(relationship_manager, faction_manager, player_node)
	hud_node.set_npcs(npcs)
	dialogue_manager.setup(relationship_manager, faction_manager, player_node)

	# Connect dialogue signals
	dialogue_manager.dialogue_started.connect(_on_dialogue_started)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_manager.relationship_notification.connect(_on_relationship_notification)
	dialogue_manager.combat_requested.connect(func(npc): start_combat_with(npc))

	# Connect combat log to HUD
	combat_manager.combat_log_updated.connect(func(msg):
		hud_node.add_log_entry(msg, Color(0.9, 0.8, 0.7))
	)

# --- Input / Movement ---

func _input(event: InputEvent) -> void:
	if current_state != GameState.EXPLORING:
		return
	var direction := Vector2i.ZERO
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_W, KEY_UP:    direction = Vector2i(0, -1)
			KEY_S, KEY_DOWN:  direction = Vector2i(0, 1)
			KEY_A, KEY_LEFT:  direction = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: direction = Vector2i(1, 0)
			KEY_E:
				if pending_npc != null:
					_start_interaction(pending_npc)
				return

	if direction != Vector2i.ZERO:
		player_node.try_move(direction, npcs)
		_check_npc_proximity()

func _check_npc_proximity() -> void:
	var adjacent_dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	pending_npc = null
	for npc in npcs:
		if not (npc is NPCCharacter) or not npc.is_alive:
			continue
		for d in adjacent_dirs:
			if player_node.tile_pos + d == npc.tile_pos:
				pending_npc = npc
				hud_node.add_log_entry(
					"[E] Interact with %s the %s" % [
						npc.character.name,
						NPCCharacter.ROLE_NAMES.get(npc.npc_role, "?")
					],
					Color(0.8, 0.9, 0.5)
				)
				return

# --- Interaction flow ---

func _start_interaction(npc: NPCCharacter) -> void:
	current_state = GameState.DIALOGUE
	dialogue_manager.start_dialogue(npc)

func _on_dialogue_started(npc: NPCCharacter, greeting: String, options: Array) -> void:
	_hide_all_overlays()
	_show_dialogue_ui(npc, greeting, options)

func _show_dialogue_ui(npc: NPCCharacter, greeting: String, options: Array) -> void:
	var ui_layer := _get_or_create_ui_layer()

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(120, 400)
	dialogue_panel.size = Vector2(1040, 290)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.96)
	style.border_color = Color(0.5, 0.5, 0.8)
	style.set_border_width_all(2)
	dialogue_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(dialogue_panel)

	# NPC name header
	var npc_color: Color = NPCCharacter.ROLE_COLORS.get(npc.npc_role, Color.WHITE)
	var header := Label.new()
	header.text = "%s  [%s]" % [npc.character.name, NPCCharacter.ROLE_NAMES.get(npc.npc_role, "?")]
	header.position = Vector2(12, 10)
	header.size = Vector2(700, 24)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", npc_color)
	dialogue_panel.add_child(header)

	# Relationship status
	var rel = relationship_manager.get_relationship(player_node.character, npc.character)
	var rel_str: String = "Neutral"
	var rel_color: Color = Color(0.8, 0.8, 0.2)
	var intensity_val: int = 0
	if rel != null:
		var rt: int = rel.get_perspective(npc.character)
		rel_str = _rel_name(rt)
		rel_color = _rel_color(rt)
		intensity_val = rel.intensity

	var rel_lbl := Label.new()
	rel_lbl.text = "Relationship: %s  (Intensity: %d)" % [rel_str, intensity_val]
	rel_lbl.position = Vector2(12, 36)
	rel_lbl.size = Vector2(700, 18)
	rel_lbl.add_theme_font_size_override("font_size", 11)
	rel_lbl.add_theme_color_override("font_color", rel_color)
	dialogue_panel.add_child(rel_lbl)

	# Greeting text
	var greet_lbl := Label.new()
	greet_lbl.text = "\"%s\"" % greeting
	greet_lbl.position = Vector2(12, 58)
	greet_lbl.size = Vector2(1016, 40)
	greet_lbl.add_theme_font_size_override("font_size", 14)
	greet_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	greet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_panel.add_child(greet_lbl)

	# Choice buttons (horizontal row)
	var btn_x: float = 10.0
	var btn_w: float = (1020.0 / maxi(options.size(), 1)) - 5.0
	btn_w = minf(btn_w, 190.0)
	for opt in options:
		var btn := Button.new()
		btn.text = opt.get("text", "...")
		btn.position = Vector2(btn_x, 106)
		btn.size = Vector2(btn_w, 52)
		btn.add_theme_font_size_override("font_size", 12)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		var captured_opt = opt
		btn.pressed.connect(func(): dialogue_manager.choose_option(captured_opt))
		dialogue_panel.add_child(btn)
		btn_x += btn_w + 6.0

func _on_dialogue_ended(_npc: NPCCharacter) -> void:
	if dialogue_panel != null and is_instance_valid(dialogue_panel):
		dialogue_panel.queue_free()
		dialogue_panel = null
	if current_state == GameState.DIALOGUE:
		current_state = GameState.EXPLORING

func _on_relationship_notification(text: String, color: Color) -> void:
	if hud_node:
		hud_node.show_notification(text, color)
		hud_node.add_log_entry(text, color)
		if hud_node.rel_panel_visible:
			hud_node._refresh_relationship_panel()

# --- Combat flow ---

func start_combat_with(npc: NPCCharacter) -> void:
	current_state = GameState.COMBAT
	_hide_all_overlays()
	combat_manager.start_combat(player_node, npc, relationship_manager, faction_manager)
	_show_combat_ui(npc)

func _show_combat_ui(npc: NPCCharacter) -> void:
	var ui_layer := _get_or_create_ui_layer()
	combat_panel = Panel.new()
	combat_panel.position = Vector2(120, 60)
	combat_panel.size = Vector2(1040, 600)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.04, 0.97)
	style.border_color = Color(0.7, 0.2, 0.2)
	style.set_border_width_all(2)
	combat_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(combat_panel)

	# Header
	var header := Label.new()
	header.text = "COMBAT"
	header.position = Vector2(12, 10)
	header.size = Vector2(500, 30)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	combat_panel.add_child(header)

	# HP labels
	var player_hp_label := Label.new()
	player_hp_label.name = "PlayerHPLabel"
	player_hp_label.position = Vector2(12, 46)
	player_hp_label.size = Vector2(460, 22)
	player_hp_label.add_theme_font_size_override("font_size", 14)
	player_hp_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	combat_panel.add_child(player_hp_label)

	var enemy_hp_label := Label.new()
	enemy_hp_label.name = "EnemyHPLabel"
	enemy_hp_label.position = Vector2(560, 46)
	enemy_hp_label.size = Vector2(460, 22)
	enemy_hp_label.add_theme_font_size_override("font_size", 14)
	enemy_hp_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	combat_panel.add_child(enemy_hp_label)

	# Combat log
	var log_label := RichTextLabel.new()
	log_label.name = "CombatLog"
	log_label.bbcode_enabled = true
	log_label.position = Vector2(12, 76)
	log_label.size = Vector2(1016, 350)
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 12)
	combat_panel.add_child(log_label)
	for entry in combat_manager.combat_log:
		log_label.append_text(entry + "\n")

	# Connect log signal
	if not combat_manager.combat_log_updated.is_connected(_on_combat_log_updated):
		combat_manager.combat_log_updated.connect(_on_combat_log_updated)

	# Action buttons
	var actions := [
		{"text": "Attack", "action": "attack"},
		{"text": "Defend", "action": "defend"},
		{"text": "Power Strike", "action": "special"},
		{"text": "Flee", "action": "flee"},
		{"text": "Show Mercy", "action": "mercy"}
	]
	var btn_x: float = 12.0
	for act in actions:
		var btn := Button.new()
		btn.name = "Btn_" + act["action"]
		btn.text = act["text"]
		btn.position = Vector2(btn_x, 438)
		btn.size = Vector2(196, 50)
		btn.add_theme_font_size_override("font_size", 14)
		var captured: String = act["action"]
		btn.pressed.connect(func(): _on_combat_action(captured))
		combat_panel.add_child(btn)
		btn_x += 202.0

	_refresh_combat_hp_labels()

	if not combat_manager.combat_ended.is_connected(_on_combat_ended):
		combat_manager.combat_ended.connect(_on_combat_ended)
	if not combat_manager.player_turn_started.is_connected(_on_player_turn_started):
		combat_manager.player_turn_started.connect(_on_player_turn_started)
	if not combat_manager.enemy_turn_started.is_connected(_on_enemy_turn_started):
		combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)

func _on_combat_log_updated(msg: String) -> void:
	var log = _find_combat_log()
	if log:
		log.append_text(msg + "\n")
	_refresh_combat_hp_labels()

func _refresh_combat_hp_labels() -> void:
	if combat_panel == null or not is_instance_valid(combat_panel):
		return
	var p_lbl = combat_panel.get_node_or_null("PlayerHPLabel")
	var e_lbl = combat_panel.get_node_or_null("EnemyHPLabel")
	if p_lbl and player_node:
		p_lbl.text = "You: %d / %d HP" % [player_node.hp, player_node.max_hp]
	if e_lbl and combat_manager.enemy:
		e_lbl.text = "%s: %d / %d HP" % [
			combat_manager.enemy.character.name,
			combat_manager.enemy.hp, combat_manager.enemy.max_hp
		]

func _find_combat_log() -> RichTextLabel:
	if combat_panel == null or not is_instance_valid(combat_panel):
		return null
	return combat_panel.get_node_or_null("CombatLog")

func _on_player_turn_started() -> void:
	_set_combat_buttons_enabled(true)

func _on_enemy_turn_started() -> void:
	_set_combat_buttons_enabled(false)

func _set_combat_buttons_enabled(enabled: bool) -> void:
	if combat_panel == null or not is_instance_valid(combat_panel):
		return
	for btn_name in ["Btn_attack", "Btn_defend", "Btn_special", "Btn_flee", "Btn_mercy"]:
		var btn = combat_panel.get_node_or_null(btn_name)
		if btn:
			btn.disabled = not enabled

func _on_combat_action(action: String) -> void:
	match action:
		"attack":  combat_manager.player_attack()
		"defend":  combat_manager.player_defend()
		"special": combat_manager.player_special()
		"flee":    combat_manager.player_flee()
		"mercy":   combat_manager.player_mercy()

func _on_combat_ended(outcome: int, npc: NPCCharacter) -> void:
	current_state = GameState.POST_COMBAT
	_set_combat_buttons_enabled(false)
	match outcome:
		CombatManager.CombatState.VICTORY:
			_show_post_combat_victory(npc)
		CombatManager.CombatState.DEFEAT:
			_on_player_died()
		CombatManager.CombatState.FLED:
			_hide_all_overlays()
			current_state = GameState.EXPLORING
			hud_node.show_notification("You escaped!", Color(0.7, 0.9, 0.5))

func _show_post_combat_victory(npc: NPCCharacter) -> void:
	_hide_all_overlays()
	var ui_layer := _get_or_create_ui_layer()
	post_combat_panel = Panel.new()
	post_combat_panel.position = Vector2(340, 220)
	post_combat_panel.size = Vector2(600, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.05, 0.97)
	style.border_color = Color(0.3, 0.7, 0.3)
	style.set_border_width_all(2)
	post_combat_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(post_combat_panel)

	var title := Label.new()
	title.text = "Victory over %s!" % npc.character.name
	title.position = Vector2(12, 12)
	title.size = Vector2(576, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	post_combat_panel.add_child(title)

	var loot_gold: int = npc.gold
	player_node.gain_gold(loot_gold)
	player_node.gain_experience_from_encounter(true, RelationshipType.Type.NEUTRAL)

	var loot_lbl := Label.new()
	loot_lbl.text = "Looted %d gold! Total kills: %d" % [loot_gold, player_node.kills]
	loot_lbl.position = Vector2(12, 50)
	loot_lbl.size = Vector2(576, 22)
	loot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_lbl.add_theme_font_size_override("font_size", 13)
	loot_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	post_combat_panel.add_child(loot_lbl)

	var question := Label.new()
	question.text = "What do you do with %s?" % npc.character.name
	question.position = Vector2(12, 90)
	question.size = Vector2(576, 22)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 14)
	question.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	post_combat_panel.add_child(question)

	var btn_spare := Button.new()
	btn_spare.text = "Spare them  (builds goodwill, +Rep)"
	btn_spare.position = Vector2(40, 130)
	btn_spare.size = Vector2(520, 50)
	btn_spare.add_theme_font_size_override("font_size", 14)
	btn_spare.pressed.connect(func(): _post_combat_spare(npc))
	post_combat_panel.add_child(btn_spare)

	var btn_execute := Button.new()
	btn_execute.text = "Execute them  (permanent, breeds hatred, -Rep)"
	btn_execute.position = Vector2(40, 188)
	btn_execute.size = Vector2(520, 50)
	btn_execute.add_theme_font_size_override("font_size", 14)
	btn_execute.pressed.connect(func(): _post_combat_execute(npc))
	post_combat_panel.add_child(btn_execute)

	var recruit_btn := Button.new()
	recruit_btn.text = "Leave  (they retreat)"
	recruit_btn.position = Vector2(40, 246)
	recruit_btn.size = Vector2(520, 36)
	recruit_btn.add_theme_font_size_override("font_size", 12)
	recruit_btn.pressed.connect(func(): _end_post_combat(npc, false))
	post_combat_panel.add_child(recruit_btn)

func _post_combat_spare(npc: NPCCharacter) -> void:
	combat_manager.apply_spare(player_node.character, npc.character)
	player_node.gain_reputation(5)
	hud_node.show_notification("You spare %s. They may become an ally." % npc.character.name,
		Color(0.3, 0.9, 0.6))
	npc.hp = max(1, npc.max_hp / 4)
	npc.is_alive = true
	_end_post_combat(npc, false)

func _post_combat_execute(npc: NPCCharacter) -> void:
	combat_manager.apply_execution(player_node.character, npc.character)
	player_node.gain_reputation(-10)
	hud_node.show_notification("You execute %s." % npc.character.name, Color(0.9, 0.3, 0.1))
	npc.is_alive = false
	npc.hide()
	_end_post_combat(npc, true)

func _end_post_combat(_npc: NPCCharacter, _executed: bool) -> void:
	if post_combat_panel and is_instance_valid(post_combat_panel):
		post_combat_panel.queue_free()
		post_combat_panel = null
	if combat_panel and is_instance_valid(combat_panel):
		combat_panel.queue_free()
		combat_panel = null
	current_state = GameState.EXPLORING
	if hud_node and player_node:
		hud_node.update_player_stats(player_node)

# --- Player death ---

func _on_player_died() -> void:
	if current_state == GameState.GAME_OVER:
		return
	current_state = GameState.GAME_OVER
	_hide_all_overlays()

	# Record nemeses to legacy
	var rels: Array = relationship_manager.get_relationships_for(player_node.character)
	for rel in rels:
		var other: Character = rel.get_other(player_node.character)
		var other_rel_type: int = rel.get_perspective(other)
		if other_rel_type in [RelationshipType.Type.NEMESIS, RelationshipType.Type.RIVAL]:
			var npc_obj := _find_npc_by_char(other)
			var role_str: String = "Warrior"
			if npc_obj:
				role_str = NPCCharacter.ROLE_NAMES.get(npc_obj.npc_role, "Warrior")
			legacy_manager.record_nemesis(
				other.id, other.name, role_str, 1, rel.intensity
			)

	legacy_manager.complete_run(false, player_node.turn_count, player_node.kills, player_node.reputation)
	_show_game_over()

func _show_game_over() -> void:
	var ui_layer := _get_or_create_ui_layer()
	game_over_panel = Panel.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.03, 0.97)
	game_over_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(game_over_panel)

	var title := Label.new()
	title.text = "YOU HAVE FALLEN"
	title.position = Vector2(640 - 200, 130)
	title.size = Vector2(400, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.8, 0.15, 0.15))
	game_over_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Run #%d  |  Turns: %d  |  Kills: %d" % [
		legacy_manager.get_run_count(), player_node.turn_count, player_node.kills
	]
	subtitle.position = Vector2(640 - 250, 195)
	subtitle.size = Vector2(500, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.5, 0.4))
	game_over_panel.add_child(subtitle)

	var nemeses: Array = legacy_manager.get_legacy_nemeses()
	var y_offset: float = 245.0
	if nemeses.size() > 0:
		var nem_title := Label.new()
		nem_title.text = "Your nemeses will remember you..."
		nem_title.position = Vector2(640 - 250, y_offset)
		nem_title.size = Vector2(500, 26)
		nem_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nem_title.add_theme_font_size_override("font_size", 15)
		nem_title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.2))
		game_over_panel.add_child(nem_title)
		y_offset += 34
		for n in nemeses:
			var lbl := Label.new()
			var evolved_str: String = " [EVOLVED]" if n.get("evolved", false) else ""
			lbl.text = "• %s (%s) — will hunt you in the next run%s" % [
				n.get("name", "?"), n.get("role", "?"), evolved_str
			]
			lbl.position = Vector2(640 - 300, y_offset)
			lbl.size = Vector2(600, 22)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			game_over_panel.add_child(lbl)
			y_offset += 26

	var btn := Button.new()
	btn.text = "Begin New Run"
	btn.position = Vector2(640 - 100, 540)
	btn.size = Vector2(200, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_restart_game)
	game_over_panel.add_child(btn)

func _restart_game() -> void:
	if game_over_panel and is_instance_valid(game_over_panel):
		game_over_panel.queue_free()
		game_over_panel = null
	start_new_game()

# --- Signal handlers ---

func _on_player_moved(_new_tile: Vector2i) -> void:
	camera.position = player_node.position
	if hud_node and player_node:
		hud_node.update_player_stats(player_node)

func _on_player_stats_changed() -> void:
	if hud_node and player_node:
		hud_node.update_player_stats(player_node)

func _on_adjacent_to_npc(npc: NPCCharacter) -> void:
	pending_npc = npc

func _on_npc_defeated(npc: NPCCharacter) -> void:
	if npc.is_legacy_nemesis:
		legacy_manager.remove_nemesis(npc.character.id)
		if hud_node:
			hud_node.show_notification(
				"You defeated your nemesis %s! Their legacy ends." % npc.character.name,
				Color(0.9, 0.7, 0.1)
			)

func _on_relationship_changed(rel: Relationship, evt: RelationshipEvent) -> void:
	if player_node == null:
		return
	if not rel.involves(player_node.character):
		return
	var other: Character = rel.get_other(player_node.character)
	var new_type: int = rel.get_perspective(player_node.character)
	var type_name: String = _rel_name(new_type)
	var color: Color = _rel_color(new_type)
	if hud_node:
		hud_node.show_notification(
			"Relationship with %s: %s (intensity: %d)" % [other.name, type_name, rel.intensity],
			color
		)
		hud_node.add_log_entry(
			"[%s] -> %s (Int: %d)" % [other.name, type_name, rel.intensity],
			color
		)

# --- Helpers ---

func _hide_all_overlays() -> void:
	for overlay in [dialogue_panel, combat_panel, post_combat_panel]:
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	dialogue_panel = null
	combat_panel = null
	post_combat_panel = null

func _get_or_create_ui_layer() -> CanvasLayer:
	var existing = get_node_or_null("UILayer")
	if existing:
		return existing
	var layer := CanvasLayer.new()
	layer.name = "UILayer"
	layer.layer = 5
	add_child(layer)
	return layer

func _find_npc_by_char(char_obj: Character) -> NPCCharacter:
	for npc in npcs:
		if npc is NPCCharacter and npc.character and npc.character.id == char_obj.id:
			return npc
	return null

func _role_from_string(role_str: String) -> int:
	match role_str:
		"Warrior":  return NPCCharacter.Role.WARRIOR
		"Merchant": return NPCCharacter.Role.MERCHANT
		"Scholar":  return NPCCharacter.Role.SCHOLAR
		"Assassin": return NPCCharacter.Role.ASSASSIN
		"Leader":   return NPCCharacter.Role.LEADER
		"Healer":   return NPCCharacter.Role.HEALER
		"Scout":    return NPCCharacter.Role.SCOUT
		"Bandit":   return NPCCharacter.Role.BANDIT
	return NPCCharacter.Role.WARRIOR

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
