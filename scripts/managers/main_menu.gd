extends Node3D

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const LEVEL_SCENE_PATH = "res://scenes/levels/level.tscn" # ПРОВЕРЬ ПУТЬ!

# --- 3D КАМЕРА И МАРКЕРЫ ---
@onready var camera = $CameraRig/Camera3D
@onready var pos_intro = $CameraRig/CamPos_Intro
@onready var pos_main = $CameraRig/CamPos_Main
@onready var pos_settings = $CameraRig/CamPos_Settings
@onready var pos_lobby = $CameraRig/CamPos_Lobby

# --- ГЛАВНЫЕ КОНТЕЙНЕРЫ ИНТЕРФЕЙСА ---
@onready var ui_intro = $CanvasLayer/UI_Intro
@onready var ui_main = $CanvasLayer/UI_Main
@onready var ui_settings = $CanvasLayer/UI_Settings
@onready var ui_lobby = $CanvasLayer/UI_Lobby

# --- ВНУТРЕННИЕ МЕНЮ (ГЛАВНЫЙ ЭКРАН) ---
@onready var start_menu = $CanvasLayer/UI_Main/StartMenu
@onready var multi_menu = $CanvasLayer/UI_Main/MultiSelect

# --- ЭЛЕМЕНТЫ МЕНЮ ---
@onready var ip_input = $CanvasLayer/UI_Main/MultiSelect/AddressInput
@onready var player_list = $CanvasLayer/UI_Lobby/VBoxContainer/PlayerList

# --- КНОПКИ (ГЛАВНЫЙ ЭКРАН) ---
@onready var btn_intro_start = $CanvasLayer/UI_Intro/Btn_IntroStart

@onready var btn_single = start_menu.get_node("Btn_Single")
@onready var btn_multi = start_menu.get_node("Btn_Multi")
@onready var btn_settings = start_menu.get_node("Btn_Settings")
@onready var btn_quit = start_menu.get_node("Btn_Quit")

@onready var btn_host = multi_menu.get_node("Btn_Host")
@onready var btn_join = multi_menu.get_node("Btn_Join")
@onready var btn_back_multi = multi_menu.get_node("Btn_Back")

# --- КНОПКИ (ДРУГИЕ ЭКРАНЫ) ---
@onready var btn_back_settings = $CanvasLayer/UI_Settings/Button # Или Btn_BackSettings
@onready var btn_start_game = $CanvasLayer/UI_Lobby/VBoxContainer/Btn_Start
@onready var btn_leave_lobby = $CanvasLayer/UI_Lobby/VBoxContainer/Btn_Leave

# --- ЭЛЕМЕНТЫ НАСТРОЕК (НОВОЕ) ---
# Убедись, что пути совпадают с твоей сценой!
@onready var check_full = $CanvasLayer/UI_Settings/TabContainer/Video/Check_Fullscreen
@onready var check_vsync = $CanvasLayer/UI_Settings/TabContainer/Video/Check_VSync
@onready var check_low = $CanvasLayer/UI_Settings/TabContainer/Video/Check_LowQuality
@onready var slider_res = $CanvasLayer/UI_Settings/TabContainer/Video/Slider_Res
@onready var slider_audio = $CanvasLayer/UI_Settings/TabContainer/Audio/HSlider

func _ready():
	# 1. Настройка при старте (Интро)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.global_transform = pos_intro.global_transform
	
	# Скрываем всё лишнее, показываем Интро
	ui_intro.show()
	ui_main.hide()
	ui_settings.hide()
	ui_lobby.hide()
	
	start_menu.show()
	multi_menu.hide()
	
	# 2. ПОДКЛЮЧЕНИЕ ГРАФИЧЕСКИХ НАСТРОЕК (НОВОЕ)
	# Подключаем сигналы к нашему SettingsManager
	check_full.toggled.connect(SettingsManager.set_fullscreen)
	check_vsync.toggled.connect(SettingsManager.set_vsync)
	check_low.toggled.connect(SettingsManager.set_low_quality)
	slider_res.value_changed.connect(SettingsManager.set_resolution_scale)
	slider_audio.value_changed.connect(SettingsManager.set_volume)

	var current_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	slider_audio.value = db_to_linear(current_db)
	# Синхронизируем галочки с реальным состоянием окна
	check_full.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	check_vsync.button_pressed = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
	slider_res.value = get_viewport().scaling_3d_scale
	

	
	# 3. ПОДКЛЮЧЕНИЕ НАВИГАЦИИ
	
	# Интро -> Главное меню
	btn_intro_start.pressed.connect(func(): _move_camera(pos_main, ui_main))
	
	# Главное -> Настройки
	btn_settings.pressed.connect(func(): _move_camera(pos_settings, ui_settings))
	btn_back_settings.pressed.connect(func(): _move_camera(pos_main, ui_main))
	
	# Переключение внутри Главного (Мультиплеер)
	btn_multi.pressed.connect(func(): 
		start_menu.hide()
		multi_menu.show()
	)
	btn_back_multi.pressed.connect(func():
		multi_menu.hide()
		start_menu.show()
	)
	
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	# 4. ПОДКЛЮЧЕНИЕ ИГРОВОЙ ЛОГИКИ
	btn_single.pressed.connect(_on_single_pressed)
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_start_game.pressed.connect(_on_start_game_pressed)
	btn_leave_lobby.pressed.connect(_on_leave_lobby_pressed)
	
	# Сетевые сигналы
	multiplayer.peer_connected.connect(_update_lobby_list)
	multiplayer.peer_disconnected.connect(_update_lobby_list)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connect_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- КАМЕРА ---

func _move_camera(target_marker: Marker3D, target_ui: Control):
	# Скрываем все UI во время полета
	ui_intro.hide()
	ui_main.hide()
	ui_settings.hide()
	ui_lobby.hide()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera, "global_transform", target_marker.global_transform, 1.2)
	
	await tween.finished
	target_ui.show()

# --- СЕТЬ ---

func _on_single_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 1)
	multiplayer.multiplayer_peer = peer
	_load_game_level()

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 4)
	if error != OK:
		print("Ошибка создания сервера: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	_move_camera(pos_lobby, ui_lobby)
	_update_lobby_list()
	btn_start_game.show()

func _on_join_pressed():
	var ip = ip_input.text
	if ip == "": ip = DEFAULT_SERVER_IP
	
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		print("Ошибка создания клиента")
		return
	multiplayer.multiplayer_peer = peer

func _on_connected_ok():
	_move_camera(pos_lobby, ui_lobby)
	_update_lobby_list()
	btn_start_game.hide()

func _on_connect_fail():
	print("Не удалось подключиться")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	_move_camera(pos_main, ui_main)
	start_menu.show()
	multi_menu.hide()

func _on_leave_lobby_pressed():
	multiplayer.multiplayer_peer = null
	_move_camera(pos_main, ui_main)
	start_menu.show()
	multi_menu.hide()

# --- ЛОББИ (ИСПРАВЛЕНО) ---

func _update_lobby_list(_id = 0):
	player_list.clear()
	
	# Конвертируем PackedInt32Array в Array, чтобы работал push_front
	var peers = Array(multiplayer.get_peers())
	peers.push_front(multiplayer.get_unique_id())
	
	for p_id in peers:
		var p_name = "Игрок " + str(p_id)
		if p_id == multiplayer.get_unique_id():
			p_name += " (Вы)"
		if p_id == 1:
			p_name += " [HOST]"
		player_list.add_item(p_name)

# --- ЗАПУСК ---

func _on_start_game_pressed():
	start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_game_rpc():
	_load_game_level()

func _load_game_level():
	get_tree().change_scene_to_file(LEVEL_SCENE_PATH)
