extends CharacterBody3D

# --- НАСТРОЙКИ ДВИЖЕНИЯ ---
@export_category("Movement")
@export var WALK_SPEED: float = 5.0
@export var SPRINT_SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 4.5
@export var MOUSE_SENSITIVITY: float = 0.003
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- НАСТРОЙКИ СТАМИНЫ ---
@export_category("Stamina")
@export var MAX_STAMINA: float = 100.0
@export var STAMINA_DRAIN: float = 20.0 # Трата в секунду
@export var STAMINA_REGEN: float = 10.0 # Восстановление в секунду

@export_category("Flashlight")
@export var FLASHLIGHT_BATTERY: float = 100.0
@export var FLASHLIGHT_DRAIN: float = 2.0 

# --- ССЫЛКИ НА НОДЫ ---
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var spectator_arm = $SpectatorArm
@onready var death_screen = $CanvasLayer/DeathScreen
@onready var stamina_overlay = $CanvasLayer/StaminaOverlay
@onready var flashlight = $Head/Flashlight
@onready var footsteps_player = $FootstepsPlayer # Убедись, что эта нода есть!
@onready var interaction_ray = $Head/InteractionRay

# --- ПЕРЕМЕННЫЕ СОСТОЯНИЯ ---
var spectate_target: Node3D = null
var spec_rotation_x = 0.0
var spec_rotation_y = 0.0

var spawned = false           # Заморозка при старте/смерти
var current_stamina = 0.0
var is_exhausted = false      # Одышка

# Звук шагов
var step_timer = 0.0
var step_interval = 0.6

@export var current_battery: float = 100.0
var flashlight_cooldown: float = 0.0 # Защита от спама кнопкой

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("player")
	current_stamina = MAX_STAMINA
	
	if death_screen: death_screen.hide()
	if stamina_overlay: stamina_overlay.color.a = 0.0
	
	# Режим призрака на 2 секунды (проходим сквозь других)
	set_collision_mask_value(2, false)
	get_tree().create_timer(2.0).timeout.connect(func(): set_collision_mask_value(2, true))

	if not is_multiplayer_authority():
		camera.current = false
		set_physics_process(false)
		set_process_input(false)
		return
	
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spectator_arm.set_as_top_level(true)

# --- RPC: РАЗМОРОЗКА ПРИ СПАВНЕ ---
@rpc("any_peer", "call_local", "reliable")
func init_spawn(start_pos, start_rot_y):
	global_position = start_pos
	rotation.y = start_rot_y
	velocity = Vector3.ZERO
	spawned = true
	print("СИСТЕМА: Игрок " + name + " разморожен.")

func _input(event):

	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	# БЛОКИРОВКА: Если не заспавнен И мы не в режиме зрителя -> выход
	if not spawned and spectate_target == null: return 
	
	if event.is_action_pressed("flashlight") and is_multiplayer_authority():
		toggle_flashlight()
	
	# Вращение мыши
	if event is InputEventMouseMotion:
		# Если ЖИВЫ (1-е лицо)
		if is_multiplayer_authority() and visible:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
			
		# Если МЕРТВЫ (Наблюдатель, 3-е лицо)
		elif is_multiplayer_authority() and spectate_target:
			spec_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
			spec_rotation_y -= event.relative.x * MOUSE_SENSITIVITY
			spec_rotation_x = clamp(spec_rotation_x, deg_to_rad(-90), deg_to_rad(60))
			
			spectator_arm.rotation.x = spec_rotation_x
			spectator_arm.rotation.y = spec_rotation_y
		
	if event.is_action_pressed("interact"):
		if is_multiplayer_authority():
			_try_interact()


func _physics_process(delta):
	if not spawned: return

	if is_multiplayer_authority() and visible:
		# Гравитация
		if not is_on_floor():
			velocity.y -= gravity * delta

		# Прыжок
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Движение
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# --- СТАМИНА ---
		if current_stamina <= 0: is_exhausted = true
		elif current_stamina >= 25.0: is_exhausted = false # Восстановились

		var is_sprinting = Input.is_action_pressed("sprint") and direction.length() > 0 and not is_exhausted
		
		var current_speed = WALK_SPEED
		if is_sprinting:
			current_speed = SPRINT_SPEED
			current_stamina -= STAMINA_DRAIN * delta
		else:
			current_stamina += STAMINA_REGEN * delta
		
		current_stamina = clamp(current_stamina, 0, MAX_STAMINA)
		
		# Визуал (Виньетка)
		if stamina_overlay and stamina_overlay.material:
			var effect_value = remap(current_stamina, MAX_STAMINA, 0, 0.0, 1.0)
			stamina_overlay.material.set_shader_parameter("intensity", effect_value)
		
		# Применение скорости
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)

		#ШАГИ
		if is_on_floor() and velocity.length() > 1.0:
			step_interval = 0.35 if is_sprinting else 0.6
			step_timer += delta
			if step_timer >= step_interval:
				step_timer = 0.0
				play_footstep.rpc(is_sprinting) 
		else:
				step_timer = step_interval
		move_and_slide()
		if flashlight_cooldown > 0:
			flashlight_cooldown -= delta

		if is_multiplayer_authority():
			_process_flashlight(delta)

		


# --- ЗВУК ШАГОВ ---
@rpc("call_local")
func play_footstep(sprinting: bool):
	if footsteps_player:
		# Устанавливаем базовую скорость звука
		# 1.0 - нормальная, 1.4 - на 40% быстрее и выше
		var base_pitch = 1.4 if sprinting else 1.2
		
		# Добавляем небольшую случайность, чтобы шаги не были монотонными
		footsteps_player.pitch_scale = base_pitch + randf_range(-0.1, 0.1)
		footsteps_player.play()

# --- КАМЕРА НАБЛЮДАТЕЛЯ ---
func _process(delta):
	# --- КАМЕРА НАБЛЮДАТЕЛЯ (твой старый код) ---
	if spectate_target and is_instance_valid(spectate_target):
		if not spectate_target.visible:
			_start_spectating()
			return
		var target_pos = spectate_target.global_position + Vector3(0, 1.5, 0)
		spectator_arm.global_position = spectator_arm.global_position.lerp(target_pos, delta * 20.0)
	elif visible:
		spectator_arm.global_position = global_position + Vector3(0, 1.5, 0)
		
	# --- НОВОЕ: ВИЗУАЛ МОРГАНИЯ ФОНАРИКА (Работает у всех) ---
	# Мы проверяем flashlight.visible, который уже синхронизирован через RPC
	if flashlight.visible:
		# Проверяем заряд (он теперь синхронизирован через MultiplayerSynchronizer)
		if current_battery < 25.0:
			# Эффект моргания
			if randf() > 0.85:
				flashlight.light_energy = randf_range(0.1, 0.8)
			else:
				flashlight.light_energy = 1.0
		else:
			# Если заряд восстановился (или еще не сел)
			if flashlight.light_energy != 1.0:
				flashlight.light_energy = 1.0

# --- СМЕРТЬ ---
@rpc("any_peer", "call_local", "reliable")
func kill_player():
	print("Игрок " + name + " погиб!")
	set_physics_process(false)
	spawned = false # Отключаем WASD
	hide()
	$CollisionShape3D.disabled = true
	
	# Убираем виньетку
	if stamina_overlay: 
		stamina_overlay.hide()
		if stamina_overlay.material:
			stamina_overlay.material.set_shader_parameter("intensity", 0.0)
	
	if is_multiplayer_authority():
		if death_screen: death_screen.show()
		await get_tree().create_timer(2.0).timeout
		_start_spectating()

func _start_spectating():
	var players = get_tree().get_nodes_in_group("player")
	spectate_target = null
	for p in players:
		if p != self and p.visible:
			spectate_target = p
			break
	
	if spectate_target:
		if death_screen: death_screen.hide()
		camera.reparent(spectator_arm, false)
		
		# Сбрасываем поворот
		spec_rotation_y = rotation.y 
		spectator_arm.rotation.y = spec_rotation_y
	else:
		if death_screen: 
			death_screen.show()
			# Тут можно написать "GAME OVER"
func _try_interact():
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		
		# Проверяем, есть ли у объекта метод "interact"
		# Это универсальный способ: плевать, дверь это или кнопк
		if collider.has_method("interact"):
			collider.interact()

# --- Новая функция в player.gd ---




func toggle_flashlight():
	# Если прошло слишком мало времени с прошлого клика (0.2 сек)
	if flashlight_cooldown > 0:
		return
		
	# Если батарейка села — включать нельзя
	if not flashlight.visible and current_battery <= 0:
		# Тут можно проиграть звук "Click_Empty"
		return 

	# Ставим кулдаун и отправляем команду по сети
	flashlight_cooldown = 0.2
	set_flashlight_state.rpc(not flashlight.visible)

# 2. Сетевое применение (RPC)
@rpc("any_peer", "call_local", "reliable")
func set_flashlight_state(is_on: bool):
	flashlight.visible = is_on
	
	# Если включили - проиграть звук щелчка (можно добавить AudioStreamPlayer)
	# if is_on: click_sound.play()

# 3. Трата энергии
# Эта функция вызывается только у Владельца (в _physics_process)
func _process_flashlight(delta):
	# Если фонарик выключен - энергию не тратим
	if not flashlight.visible:
		return
		
	# Тратим энергию
	current_battery -= FLASHLIGHT_DRAIN * delta
	
	# Если села батарейка
	if current_battery <= 0:
		current_battery = 0
		print("Батарейка села!")
		set_flashlight_state.rpc(false)


func recharge_battery(amount: float) -> bool:
	if current_battery >= FLASHLIGHT_BATTERY:
		print("Батарейка полная, зарядка не требуется.")
		return false
		
	current_battery += amount
	if current_battery > FLASHLIGHT_BATTERY:
		current_battery = FLASHLIGHT_BATTERY
		
	print("Фонарик заряжен! Заряд: ", current_battery)
	
	# Возвращаем яркость в норму (на случай, если она моргала)
	if flashlight: flashlight.light_energy = 1.0
	
	return true