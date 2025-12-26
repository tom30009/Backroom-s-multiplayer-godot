extends Node3D

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const LEVEL_SCENE_PATH = "res://scenes/levels/level.tscn"

# --- 3D КАМЕРА И МАРКЕРЫ ---
@onready var camera = $CameraRig/Camera3D
@onready var pos_intro = $CameraRig/CamPos_Intro       # <--- НОВОЕ
@onready var pos_main = $CameraRig/CamPos_Main
@onready var pos_settings = $CameraRig/CamPos_Settings
@onready var pos_lobby = $CameraRig/CamPos_Lobby

# --- ГЛАВНЫЕ КОНТЕЙНЕРЫ ИНТЕРФЕЙСА ---
@onready var ui_intro = $CanvasLayer/UI_Intro           # <--- НОВОЕ
@onready var ui_main = $CanvasLayer/UI_Main
@onready var ui_settings = $CanvasLayer/UI_Settings
@onready var ui_lobby = $CanvasLayer/UI_Lobby

# --- ЭЛЕМЕНТЫ МЕНЮ ---
@onready var btn_intro_start = $CanvasLayer/UI_Intro/Btn_IntroStart # <--- НОВОЕ

# (Остальные пути как были)
@onready var start_menu = $CanvasLayer/UI_Main/StartMenu
@onready var multi_menu = $CanvasLayer/UI_Main/MultiSelect
@onready var ip_input = $CanvasLayer/UI_Main/MultiSelect/AddressInput
@onready var player_list = $CanvasLayer/UI_Lobby/VBoxContainer/PlayerList

@onready var btn_single = start_menu.get_node("Btn_Single")
@onready var btn_multi = start_menu.get_node("Btn_Multi")
@onready var btn_settings = start_menu.get_node("Btn_Settings")
@onready var btn_quit = start_menu.get_node("Btn_Quit")

@onready var btn_host = multi_menu.get_node("Btn_Host")
@onready var btn_join = multi_menu.get_node("Btn_Join")
@onready var btn_back_multi = multi_menu.get_node("Btn_Back")

# Проверь имя кнопки (Button или Btn_BackSettings) в своей сцене!
@onready var btn_back_settings = $CanvasLayer/UI_Settings/Button 
@onready var btn_start_game = $CanvasLayer/UI_Lobby/VBoxContainer/Btn_Start
@onready var btn_leave_lobby = $CanvasLayer/UI_Lobby/VBoxContainer/Btn_Leave


func _ready():
	# Настройка при старте: СТАВИМ КАМЕРУ НА ИНТРО
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.global_transform = pos_intro.global_transform # <--- Стартуем с общего плана
	
	# Показываем только Интро
	ui_intro.show()
	ui_main.hide()
	ui_settings.hide()
	ui_lobby.hide()
	
	# Сбрасываем подменю
	start_menu.show()
	multi_menu.hide()
	
	# --- ПОДКЛЮЧЕНИЕ КНОПКИ ИНТРО ---
	# Нажали старт -> летим к монитору
	btn_intro_start.pressed.connect(func(): _move_camera(pos_main, ui_main))
	
	# --- НАВИГАЦИЯ ---
	btn_settings.pressed.connect(func(): _move_camera(pos_settings, ui_settings))
	btn_back_settings.pressed.connect(func(): _move_camera(pos_main, ui_main))
	
	btn_multi.pressed.connect(func(): 
		start_menu.hide()
		multi_menu.show()
	)
	btn_back_multi.pressed.connect(func():
		multi_menu.hide()
		start_menu.show()
	)
	
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	# --- ЛОГИКА ИГРЫ ---
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

# --- ДВИЖЕНИЕ КАМЕРЫ ---
func _move_camera(target_marker: Marker3D, target_ui: Control):
	# Скрываем вообще всё во время полета
	ui_intro.hide()
	ui_main.hide()
	ui_settings.hide()
	ui_lobby.hide()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Летим 1.5 секунды (чуть медленнее для красоты)
	tween.tween_property(camera, "global_transform", target_marker.global_transform, 1.5)
	
	await tween.finished
	target_ui.show()

# --- СЕТЕВАЯ ЛОГИКА ---

func _on_single_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 1)
	multiplayer.multiplayer_peer = peer
	print("Запуск одиночной игры...")
	_load_game_level()

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 4)
	if error != OK:
		print("Ошибка: " + str(error))
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
		print("Ошибка клиента")
		return
	multiplayer.multiplayer_peer = peer

func _on_connected_ok():
	_move_camera(pos_lobby, ui_lobby)
	_update_lobby_list()
	btn_start_game.hide()

func _on_connect_fail():
	multiplayer.multiplayer_peer = null
	# Тут можно добавить Alert Dialog

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

# --- ИСПРАВЛЕННАЯ ФУНКЦИЯ ЛОББИ ---
func _update_lobby_list(_id = 0):
	player_list.clear()
	
	# --- ФИКС ЗДЕСЬ ---
	# Превращаем PackedInt32Array в обычный Array
	var peers = Array(multiplayer.get_peers())
	peers.push_front(multiplayer.get_unique_id())
	
	for p_id in peers:
		var p_name = "Игрок " + str(p_id)
		if p_id == multiplayer.get_unique_id():
			p_name += " (Вы)"
		if p_id == 1:
			p_name += " [HOST]"
		player_list.add_item(p_name)

func _on_start_game_pressed():
	start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_game_rpc():
	_load_game_level()

func _load_game_level():
	get_tree().change_scene_to_file(LEVEL_SCENE_PATH)
