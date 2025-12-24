extends Control

# ПОРТ и IP
# 127.0.0.1 (localhost) используется для теста на одном компьютере.
# Чтобы играть с другом через интернет, здесь нужен будет реальный IP хоста (или VPN типа Radmin/Hamachi).
const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"

# Ссылки на элементы интерфейса (проверь, чтобы имена совпадали с твоими нодами!)
@onready var address_entry = $VBoxContainer/AddressEntry # Если ты добавил поле ввода IP
@onready var host_button = $VBoxContainer/ButtonHost
@onready var join_button = $VBoxContainer/ButtonJoin

func _ready():
	# Подключаем сигналы нажатия кнопок к функциям в коде
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# Подписываемся на важные сигналы сетевой системы Godot
	# Когда мы успешно подключились к серверу
	multiplayer.connected_to_server.connect(_on_connected_ok)
	# Когда не удалось подключиться
	multiplayer.connection_failed.connect(_on_connected_fail)
	# Когда кто-то другой (или мы сами на сервере) подключился
	multiplayer.peer_connected.connect(_on_player_connected)
	# Когда кто-то отключился
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	$VBoxContainer/ButtonStart.pressed.connect(_load_game_level)
# --- ЛОГИКА ХОСТА (СЕРВЕРА) ---
func _on_host_pressed():
	# Создаем объект "пир" (участник сети) на основе ENet (стандартная библиотека Godot)
	var peer = ENetMultiplayerPeer.new()
	
	# Пытаемся создать сервер
	var error = peer.create_server(PORT, 4) # 4 - макс. кол-во игроков
	
	if error != OK:
		print("ОШИБКА: Не удалось создать сервер! Код: " + str(error))
		return
		
	# Присваиваем созданный peer глобальному объекту multiplayer
	multiplayer.multiplayer_peer = peer
	
	print("СЕРВЕР ЗАПУЩЕН. Ожидание игроков...")
	$VBoxContainer/ButtonStart.show()

# --- ЛОГИКА КЛИЕНТА (ИГРОКА) ---
func _on_join_pressed():
	var peer = ENetMultiplayerPeer.new()
	
	# Берем IP из поля ввода или используем дефолтный
	var ip = DEFAULT_SERVER_IP
	if address_entry and address_entry.text != "":
		ip = address_entry.text
		
	print("Попытка подключения к: " + ip)
	
	# Пытаемся создать клиента
	var error = peer.create_client(ip, PORT)
	
	if error != OK:
		print("ОШИБКА: Не удалось создать клиент! Код: " + str(error))
		return
		
	multiplayer.multiplayer_peer = peer

# --- ОБРАБОТЧИКИ СОБЫТИЙ ---

func _on_connected_ok():
	print("УСПЕХ! Мы подключились к серверу.")
	# Клиент не загружает уровень сам! Он ждет, пока сервер скажет ему это сделать
	# (но в Godot 4 это часто решается через MultiplayerSpawner, до которого мы дойдем)

func _on_connected_fail():
	print("ОШИБКА: Не удалось подключиться к серверу.")
	multiplayer.multiplayer_peer = null # Сбрасываем peer

func _on_player_connected(id):
	print("Игрок подключился! ID: " + str(id))

func _on_player_disconnected(id):
	print("Игрок отключился. ID: " + str(id))

func _load_game_level():
	# Вызываем функцию start_game на всех компьютерах (RPC)
	# call_deferred нужен, чтобы делать это безопасно для движка
	start_game.rpc()

# Аннотация @rpc("any_peer", "call_local") означает:
# any_peer - функцию можно вызвать кто угодно (в данном случае сервер вызывает всем)
# call_local - функция выполнится и на том компе, который её вызвал (на сервере тоже)
# reliable - гарантированная доставка пакета
@rpc("any_peer", "call_local", "reliable")
func start_game():
	print("Загружаем уровень...")
	# Меняем сцену на Level.tscn
	get_tree().change_scene_to_file("res://scenes/levels/level.tscn")
	
