extends CharacterBody3D

# --- НАСТРОЙКИ ---
@export_category("AI Settings")
@export var SPEED_PATROL: float = 2.5
@export var SPEED_CHASE: float = 6.5
@export var ACCELERATION: float = 10.0

@export_category("Detection")
@export var HEARING_RANGE: float = 8.0     # Дистанция слуха (спиной)
@export var VISION_RANGE: float = 25.0     # Дальность зрения
@export var VISION_ANGLE: float = 60.0     # Угол обзора (половина конуса, итого 120 градусов)
@export var ATTACK_RANGE: float = 1.8      # Дистанция убийства
var patience_timer: float = 0.0 # Таймер терпения
const MAX_PATIENCE: float = 2.0 # Сколько секунд монстр преследует невидимку

# --- СОСТОЯНИЯ ---
enum State { IDLE, PATROL, CHASE }
var current_state: State = State.IDLE

# --- ПЕРЕМЕННЫЕ ---
var target_player: Node3D = null
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Для блуждания
@export_category("extra")
@export var patrol_wait_timer: float = 0.0
@export var patrol_wait_time: float = 3.0

# --- ССЫЛКИ НА НОДЫ ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var roam_sound: AudioStreamPlayer3D = $RoamSound
@onready var chase_sound: AudioStreamPlayer3D = $ChaseSound

func _ready():
	# Обязательно настраиваем навигацию, чтобы монстр не "прилипал" к полу
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	# Только сервер управляет монстром!
	set_physics_process(is_multiplayer_authority())

func _physics_process(delta):
	# Гравитация (чтобы не висел в воздухе)
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Логика состояний
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
	
	# Передвижение
	move_and_slide()
	
	# Поиск игроков (работает во всех состояниях)
	_scan_for_players()

# --- ЛОГИКА СОСТОЯНИЙ ---

func _process_idle(delta):
	velocity.x = move_toward(velocity.x, 0, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, 0, ACCELERATION * delta)
	
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		_pick_random_patrol_point()

func _process_patrol(delta):
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		patrol_wait_timer = patrol_wait_time
		# Шанс издать звук при остановке
		if randf() > 0.7: play_sound_rpc("roam")
		return

	_move_towards_point(nav_agent.get_next_path_position(), SPEED_PATROL, delta)

func _process_chase(delta):
	# Если игрок исчез (вышел из игры)
	if not is_instance_valid(target_player) or not target_player.spawned:
		_lost_player()
		return
	
	# Проверяем, видим ли мы игрока ПРЯМО СЕЙЧАС
	# (Используем ту же функцию _has_line_of_sight, что и для обнаружения)
	var can_see = _has_line_of_sight(target_player)
	
	if can_see:
		# ВИДИМ: Обновляем цель на текущую позицию игрока
		nav_agent.target_position = target_player.global_position
		# Сбрасываем таймер терпения (мы полны решимости)
		patience_timer = MAX_PATIENCE
	else:
		# НЕ ВИДИМ (Дверь закрылась или ушли за угол):
		# Мы НЕ обновляем target_position. Монстр бежит в последнюю точку, где видел нас.
		
		# Тикает таймер "потери интереса"
		patience_timer -= delta
		if patience_timer <= 0:
			print("Монстр потерял игрока (скрылся за дверью/стеной)")
			_lost_player()
			return

	# Стандартное движение по навигации
	# (Монстр пойдет к двери, так как это была последняя точка, которую он запомнил)
	if nav_agent.is_navigation_finished():
		# Если монстр дошел до последней точки и все еще не видит игрока
		if not can_see:
			_lost_player()
			return

	_move_towards_point(nav_agent.get_next_path_position(), SPEED_CHASE, delta)

	# Атака (только если видим)
	if can_see:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= ATTACK_RANGE:
			_attack_player(target_player)

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

func _move_towards_point(target_pos: Vector3, speed: float, delta: float):
	# Вычисляем направление
	var direction = global_position.direction_to(target_pos)
	direction.y = 0 # Не летим вверх/вниз при движении
	direction = direction.normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Плавный поворот к цели
		var target_rot = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)

func _pick_random_patrol_point():
	# Ищем случайную точку на NavMesh в радиусе 30 метров
	var random_pos = global_position + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
	# Проецируем на карту навигации, чтобы точка была проходимой
	nav_agent.target_position = random_pos
	current_state = State.PATROL

func _start_chase(player):
	if current_state != State.CHASE:
		current_state = State.CHASE
		target_player = player
		play_sound_rpc("chase")
		print("Монстр увидел игрока: ", player.name)

func _lost_player():
	target_player = null
	current_state = State.IDLE
	patrol_wait_timer = 1.0 # Небольшая пауза перед новым поиском

func _attack_player(player):
	# Вызываем функцию смерти у игрока (RPC)
	if player.has_method("kill_player"):
		player.kill_player.rpc() # Вызов на всех клиентах
		# Сбрасываем агро после убийства
		_lost_player()

# --- СИСТЕМА ОБНАРУЖЕНИЯ ---

func _scan_for_players():
	var players = get_tree().get_nodes_in_group("player")
	
	for player in players:
		if not player.spawned or not player.visible: continue
		
		var dist = global_position.distance_to(player.global_position)
		
		# 1. ПРОВЕРКА СЛУХА (360 градусов, если близко)
		if dist < HEARING_RANGE:
			# Проверка: есть ли стена между монстром и игроком?
			if _has_line_of_sight(player):
				_start_chase(player)
				return
		
		# 2. ПРОВЕРКА ЗРЕНИЯ (Конус)
		if dist < VISION_RANGE:
			# Вектор к игроку
			var dir_to_player = global_position.direction_to(player.global_position)
			# Вектор "вперед" монстра
			var forward = -global_transform.basis.z
			
			# Угол между взглядом монстра и направлением на игрока
			var angle = rad_to_deg(forward.angle_to(dir_to_player))
			
			if angle < VISION_ANGLE:
				if _has_line_of_sight(player):
					_start_chase(player)
					return

func _has_line_of_sight(target: Node3D) -> bool:
	# RayCast через код (PhysicsDirectSpaceState)
	var space_state = get_world_3d().direct_space_state
	# Стреляем лучом от глаз монстра (чуть выше центра) к голове игрока (чуть выше центра)
	var from = global_position + Vector3(0, 1.5, 0) 
	var to = target.global_position + Vector3(0, 1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Монстр не должен видеть сам себя
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Если луч попал в Игрока - видим
		if result.collider == target:
			return true
		else:
			# Попал в стену
			return false
	return true # Если ничего не задел (странно, но допустим видим)

# --- ЗВУКИ (RPC) ---

# --- ЗВУКИ (RPC) ---

@rpc("call_local")
func play_sound_rpc(sound_type: String):
	# ЗАЩИТА: Если монстр еще не загрузился в сцену, отменяем звук, чтобы не было краша
	if not is_inside_tree(): 
		return

	if sound_type == "chase":
		# Проверяем, существует ли нода звука и не играет ли она уже
		if chase_sound and chase_sound.is_inside_tree() and not chase_sound.playing:
			chase_sound.play()
			
			# Глушим звук патруля
			if roam_sound and roam_sound.is_inside_tree():
				roam_sound.stop()
				
	elif sound_type == "roam":
		if roam_sound and roam_sound.is_inside_tree() and not roam_sound.playing:
			roam_sound.pitch_scale = randf_range(0.8, 1.2)
			roam_sound.play()