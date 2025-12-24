extends Node3D

# --- ССЫЛКИ НА СЦЕНЫ ---
const PLAYER_SCENE = preload("res://scenes/Characters/Player.tscn")
const MONSTER_SCENE = preload("res://scenes/Characters/SmartMonster.tscn")
# Исправил двойное .tscn.tscn
const KEY_SCENE = preload("res://scenes/interactables/item scenes/Pickup_KeyRed.tscn.tscn")
const BATTERY_SCENE = preload("res://scenes/interactables/item scenes/battery.tscn")

# --- КОНТЕЙНЕРЫ И СПАВНЫ ---
@onready var players_container = $Players
@onready var player_spawns_container = $PlayerSpawns
@onready var monster_spawns_container = $MonsterSpawns
@onready var monster_timer = $MonsterTimer
@onready var interactables_container = $Interactables

# Новые раздельные контейнеры спавна
@onready var key_spawns_container = $KeySpawns
@onready var battery_spawns_container = $BatterySpawns

func _ready():
	# Если просто запустили сцену без сети
	if not multiplayer.has_multiplayer_peer():
		return
	
	if multiplayer.is_server():
		# 1. Настройка игроков
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(del_player)
		
		add_player(1) # Хост
		for id in multiplayer.get_peers():
			add_player(id)
			
		# 2. Настройка монстра
		if not monster_timer.timeout.is_connected(_on_monster_timer_timeout):
			monster_timer.timeout.connect(_on_monster_timer_timeout)
			
		print("Запуск таймера монстра...")
		monster_timer.start()
		
		# 3. Спавн лута (Ключи и Батарейки)
		spawn_level_loot()

# --- ЛОГИКА МОНСТРА ---

func _on_monster_timer_timeout():
	spawn_monster()

func spawn_monster():
	var monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster_1"
	
	var spawns = monster_spawns_container.get_children()
	
	if spawns.size() > 0:
		var random_point = spawns.pick_random()
		monster.position = random_point.global_position
		monster.rotation.y = randf_range(0, 360)
		print("Монстр вышел на охоту в точке: " + random_point.name)
	else:
		monster.position = Vector3(0, 1, 0)
		print("ОШИБКА: Точек монстра нет!")
		
	$Enemies.add_child(monster, true)

# --- ЛОГИКА ИГРОКОВ ---

func add_player(id):
	if players_container.has_node(str(id)):
		return
		
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	players_container.add_child(player, true)
	
	# Расчет позиции спавна
	var spawn_pos = Vector3(0, 2, 0)
	var spawn_rot = 0.0
	
	var spawns = player_spawns_container.get_children()
	if spawns.size() > 0:
		var current_player_count = players_container.get_child_count()
		var spawn_index = (current_player_count - 1) % spawns.size()
		var selected_marker = spawns[spawn_index]
		
		spawn_pos = selected_marker.global_position
		spawn_rot = selected_marker.rotation.y
		print("Игрок " + str(id) + " -> Точка: " + selected_marker.name)

	# Отложенная инициализация клиента
	await get_tree().create_timer(0.2).timeout
	
	if is_instance_valid(player):
		player.init_spawn.rpc(spawn_pos, spawn_rot)

func del_player(id):
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()

# --- ЛОГИКА ЛУТА ---

func spawn_level_loot():
	print("--- НАЧИНАЮ СПАВН ЛУТА ---")
	
	# 1. Спавним 1 Ключ в точках для ключей
	spawn_items_in_group(KEY_SCENE, key_spawns_container, 1)
	
	# 2. Спавним 4 Батарейки в точках для батареек
	spawn_items_in_group(BATTERY_SCENE, battery_spawns_container, 7)

# Универсальная функция спавна
func spawn_items_in_group(scene, container_node, count):
	# Проверка на существование контейнера
	if not container_node:
		print("ОШИБКА: Контейнер спавна не найден!")
		return

	var spawns = container_node.get_children()
	
	if spawns.size() == 0:
		print("ОШИБКА: Пустой контейнер спавна: ", container_node.name)
		return
		
	spawns.shuffle()
	
	for i in range(count):
		if spawns.size() > 0:
			var point = spawns.pop_front() # Забираем точку
			
			var item = scene.instantiate()
			item.global_transform = point.global_transform
			interactables_container.add_child(item, true)
			
			print("Заспавнен ", item.name, " в ", point.name)
		else:
			print("Не хватило мест в ", container_node.name, " для всех предметов!")
			break