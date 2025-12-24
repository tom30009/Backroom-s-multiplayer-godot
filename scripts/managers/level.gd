extends Node3D

const PLAYER_SCENE = preload("res://scenes/Characters/Player.tscn")
const MONSTER_SCENE = preload("res://scenes/Characters/SmartMonster.tscn")
const KEY_SCENE = preload("res://scenes/interactables/item scenes/Pickup_KeyRed.tscn.tscn")
const BATTERY_SCENE = preload("res://scenes/interactables/item scenes/battery.tscn")

@onready var players_container = $Players
@onready var player_spawns_container = $PlayerSpawns
@onready var monster_spawns_container = $MonsterSpawns
@onready var monster_timer = $MonsterTimer
@onready var item_spawns_container = $ItemSpawns   # Точки спавна
@onready var interactables_container = $Interactables



func _ready():
	# Если просто запустили сцену без сети
	if not multiplayer.has_multiplayer_peer():
		return
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(del_player)
		
		# 1. Спавним Игроков
		add_player(1) # Хост
		for id in multiplayer.get_peers():
			add_player(id)
			
		# 2. Подключаем и запускаем таймер монстра
		if not monster_timer.timeout.is_connected(_on_monster_timer_timeout):
			monster_timer.timeout.connect(_on_monster_timer_timeout)
			
		print("Запуск таймера монстра...")
		monster_timer.start()
	if multiplayer.is_server():
		spawn_level_loot()
		

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

func add_player(id):
	if players_container.has_node(str(id)):
		return
		
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	
	# Добавляем в сцену (Игрок появляется замороженным)
	players_container.add_child(player, true)
	
	# Расчет позиции (тот же код, что был)
	var spawn_pos = Vector3(0, 2, 0)
	var spawn_rot = 0.0
	
	var spawns = player_spawns_container.get_children()
	if spawns.size() > 0:
		var current_player_count = players_container.get_child_count()
		# Важно: вычитаем 1, так как игрок уже добавлен строчкой выше
		var spawn_index = (current_player_count - 1) % spawns.size()
		var selected_marker = spawns[spawn_index]
		
		spawn_pos = selected_marker.global_position
		spawn_rot = selected_marker.rotation.y
		print("Игрок " + str(id) + " -> Точка: " + selected_marker.name)

	# --- ИСПРАВЛЕНИЕ ТУТ ---
	
	# Ждем 0.2 секунды. Этого достаточно, чтобы клиент успел создать ноду у себя
	await get_tree().create_timer(0.2).timeout
	
	# Теперь отправляем приказ "Разморозиться"
	# Проверяем, существует ли еще игрок (вдруг он вышел за эти 0.2 сек)
	if is_instance_valid(player):
		player.init_spawn.rpc(spawn_pos, spawn_rot)

func del_player(id):
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()


func spawn_random_key():
	# 1. Получаем список всех маркеров
	var spawns = item_spawns_container.get_children()
	
	if spawns.size() == 0:
		print("ОШИБКА: Нет точек спавна для предметов (ItemSpawns)!")
		return
		
	# 2. Выбираем случайную точку
	var random_point = spawns.pick_random()
	
	# 3. Создаем ключ
	var key = KEY_SCENE.instantiate()
	
	# 4. Ставим позицию и поворот как у маркера
	key.global_position = random_point.global_position
	key.rotation = random_point.rotation
	
	# 5. Добавляем в сцену.
	# Благодаря MultiplayerSpawner (который следит за interactables_container),
	# ключ появится у всех игроков автоматически!
	interactables_container.add_child(key, true)
	
	print("Ключ заспавнен в точке: ", random_point.name)

func spawn_loot():
	var spawns = item_spawns_container.get_children()
	spawns.shuffle() # Перемешиваем массив точек
	
	# Берем первую точку для ключа
	var key_point = spawns.pop_front() # Берет первый элемент и удаляет его из списка
	_spawn_item(KEY_SCENE, key_point)
	
	# Берем следующие 3 точки для батареек (если они остались)
	for i in range(3):
		if spawns.size() > 0:
			var battery_point = spawns.pop_front()
			_spawn_item(BATTERY_SCENE, battery_point)

func _spawn_item(scene, point):
	var item = scene.instantiate()
	item.global_transform = point.global_transform
	interactables_container.add_child(item, true)


func spawn_level_loot():
	# 1. Берем все доступные маркеры
	var available_spawns = item_spawns_container.get_children()
	
	# 2. Перемешиваем их случайным образом
	available_spawns.shuffle()
	
	# Проверка: хватит ли точек?
	if available_spawns.size() == 0:
		print("ОШИБКА: Нет точек ItemSpawns!")
		return

	# 3. Спавним ОДИН Ключ (берем первую точку и удаляем её из списка)
	var key_point = available_spawns.pop_front()
	_spawn_item(KEY_SCENE, key_point)
	print("Ключ: ", key_point.name)
	
	# 4. Спавним БАТАРЕЙКИ (например, 3 штуки)
	# Цикл сработает столько раз, сколько мы хотим, ИЛИ пока не кончатся точки
	var battery_count = 3
	for i in range(battery_count):
		if available_spawns.size() > 0:
			var point = available_spawns.pop_front() # Берем следующую точку
			_spawn_item(BATTERY_SCENE, point)
			print("Батарейка ", i+1, ": ", point.name)
		else:
			print("Не хватило точек спавна для всех батареек!")
			break

# Вспомогательная функция, чтобы не дублировать код
