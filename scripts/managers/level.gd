extends Node3D

# --- ССЫЛКИ НА ФАЙЛЫ ---
const PLAYER_SCENE = preload("res://scenes/Characters/Player.tscn")
const MONSTER_SCENE = preload("res://scenes/Characters/SmartMonster.tscn")
const KEY_SCENE = preload("res://scenes/interactables/item scenes/Pickup_KeyRed.tscn")
const BATTERY_SCENE = preload("res://scenes/interactables/item scenes/battery.tscn")

# --- ССЫЛКИ НА НОДЫ ---
@onready var players_container = $Players
@onready var player_spawns_container = $PlayerSpawns
@onready var monster_spawns_container = $MonsterSpawns
@onready var monster_timer = $MonsterTimer

@onready var interactables_container = $Interactables
@onready var key_spawns_container = $KeySpawns
@onready var battery_spawns_container = $BatterySpawns
@onready var item_spawner = $ItemSpawner 

func _ready():
	if not multiplayer.has_multiplayer_peer(): return
	
	# --- [ГЛАВНОЕ ИЗМЕНЕНИЕ] НАСТРОЙКА ФУНКЦИИ СПАВНА ---
	# Мы говорим спавнеру: "Когда нужно что-то создать, используй эту функцию"
	item_spawner.spawn_function = _spawn_custom_item
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(del_player)
		
		add_player(1)
		for id in multiplayer.get_peers():
			add_player(id)
			
		if not monster_timer.timeout.is_connected(_on_monster_timer_timeout):
			monster_timer.timeout.connect(_on_monster_timer_timeout)
		monster_timer.start()
		
		# Ждем чуть-чуть, чтобы всё прогрузилось
		await get_tree().create_timer(0.5).timeout
		spawn_level_loot()

# --- ФУНКЦИЯ, КОТОРАЯ СОЗДАЕТ ПРЕДМЕТЫ (РАБОТАЕТ У ВСЕХ) ---
# Эта функция вызывается Спавнером автоматически и на Сервере, и на Клиенте.
# data - это то, что мы передадим (словарь с типом предмета и позицией)
func _spawn_custom_item(data):
	var item_type = data["type"]
	var pos = data["pos"]
	var rot_y = data["rot_y"]
	
	var item_node = null
	
	# Выбираем, что создавать
	if item_type == "key":
		item_node = KEY_SCENE.instantiate()
	elif item_type == "battery":
		item_node = BATTERY_SCENE.instantiate()
		
	# Настраиваем позицию
	if item_node:
		item_node.position = pos
		item_node.rotation.y = rot_y
		
	return item_node # Возвращаем ноду, и Спавнер сам добавит её в Interactables

# --- ЛОГИКА СЕРВЕРА: РАССЫЛКА ПРИКАЗОВ ---
func spawn_level_loot():
	print("Level: --- СПАВН ЛУТА (Через spawn_function) ---")
	
	# Очищаем старое (если есть)
	for child in interactables_container.get_children():
		child.queue_free()
	
	# 1. Спавним КЛЮЧ
	spawn_group_custom("key", key_spawns_container, 1)
	
	# 2. Спавним БАТАРЕЙКИ
	spawn_group_custom("battery", battery_spawns_container, 7)

func spawn_group_custom(type_name, container, count):
	var spawns = container.get_children()
	spawns.shuffle()
	
	for i in range(count):
		if spawns.size() > 0:
			var point = spawns.pop_front()
			
			# Формируем пакет данных для спавнера
			var data = {
				"type": type_name,
				"pos": point.global_position,
				"rot_y": point.rotation.y
			}
			
			# ПРИКАЗЫВАЕМ СПАВНЕРУ СОЗДАТЬ ПРЕДМЕТ
			# Это отправит сигнал всем клиентам, и у них запустится _spawn_custom_item
			item_spawner.spawn(data)
			
			print("Level: Приказ спавна ", type_name, " в ", point.name)
		else:
			break

# --- ИГРОКИ И МОНСТР (Твой код) ---
func add_player(id):
	if players_container.has_node(str(id)): return
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	players_container.add_child(player, true)
	
	var spawn_pos = Vector3(0, 2, 0)
	var spawn_rot = 0.0
	var spawns = player_spawns_container.get_children()
	if spawns.size() > 0:
		var idx = (players_container.get_child_count() - 1) % spawns.size()
		spawn_pos = spawns[idx].global_position
		spawn_rot = spawns[idx].rotation.y

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(player):
		player.init_spawn.rpc(spawn_pos, spawn_rot)

func del_player(id):
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()

func _on_monster_timer_timeout():
	spawn_monster()

func spawn_monster():
	var monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster_1"
	var spawns = monster_spawns_container.get_children()
	if spawns.size() > 0:
		var p = spawns.pick_random()
		monster.position = p.global_position
		monster.rotation.y = randf_range(0, 360)
	else:
		monster.position = Vector3(0,1,0)
	$Enemies.add_child(monster, true)