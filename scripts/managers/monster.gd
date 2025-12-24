extends CharacterBody3D

@export var SPEED = 3.5       
@export var CHASE_SPEED = 6.0 

enum State { PATROL, CHASE }
var current_state = State.PATROL

@onready var nav_agent = $NavigationAgent3D
@onready var eyes = $Eyes 

var target_player: Node3D = null

func _ready():
	set_multiplayer_authority(1) 
	
	# --- ПРИНУДИТЕЛЬНАЯ НАСТРОЙКА ГЛАЗ (Fix) ---
	if eyes:
		eyes.enabled = true
		eyes.exclude_parent = true # Не видеть себя
		# Устанавливаем маску коллизии кодом:
		# Bit 1 (Value 1) = Стены
		# Bit 2 (Value 2) = Игроки
		# 1 + 2 = 3 (Видеть и стены, и игроков)
		eyes.collision_mask = 3 
	
	if not is_multiplayer_authority():
		set_physics_process(false)
		return

	await get_tree().physics_frame
	_get_new_patrol_location()

func _physics_process(delta):
	match current_state:
		State.PATROL:
			if nav_agent.is_navigation_finished():
				_get_new_patrol_location()
				
		State.CHASE:
			if target_player:
				nav_agent.target_position = target_player.global_position
				_check_vision()
				
				var distance = global_position.distance_to(target_player.global_position)
				# Увеличил дистанцию атаки до 2.0, чтобы легче попадал
				if distance < 2.0:
					_attack_player(target_player)

	var current_location = global_position
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * _get_speed()
	
	velocity = new_velocity
	
	if velocity.length() > 0.1:
		var look_dir = Vector2(velocity.z, velocity.x)
		rotation.y = look_dir.angle()

	move_and_slide()

func _get_speed():
	if current_state == State.CHASE:
		return CHASE_SPEED
	return SPEED

func _get_new_patrol_location():
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_dist = randf_range(5, 20)
	var target_pos = global_position + (random_dir * random_dist)
	nav_agent.target_position = target_pos

func _on_aura_body_entered(body):
	if body.is_in_group("player"): 
		print("Чую игрока: " + body.name)
		_try_spot_player(body)

func _on_aura_body_exited(body):
	if body == target_player:
		print("Игрок убежал!")
		target_player = null
		current_state = State.PATROL
		_get_new_patrol_location()

# --- ГЛАВНОЕ ИСПРАВЛЕНИЕ ЗДЕСЬ ---
func _try_spot_player(player):
	# 1. Вычисляем точку головы игрока
	var target_head_pos = player.global_position + Vector3(0, 1.5, 0)
	
	# 2. ВМЕСТО ВРАЩЕНИЯ ГЛАЗ (look_at), МЫ МЕНЯЕМ САМ ЛУЧ
	# Функция to_local переводит глобальные координаты головы игрока 
	# в локальные координаты относительно глаз монстра.
	# Это значит: "Луч должен закончиться ровно там, где голова игрока"
	eyes.target_position = eyes.to_local(target_head_pos)
	
	# 3. Обновляем луч
	eyes.force_raycast_update()
	
	if eyes.is_colliding():
		var collider = eyes.get_collider()
		
		if collider == player:
			if current_state != State.CHASE or target_player != player:
				print("Вижу игрока! Атакую!")
				current_state = State.CHASE
				target_player = player
		else:
			# Отладка: видим стену?
			# print("Луч уперся в: " + collider.name)
			pass
	else:
		# Если луч никуда не попал, возможно дистанция слишком велика,
		# но так как мы задаем target_position прямо в игрока, 
		# это может значить только глюк физики или выключенную маску.
		# print("Луч не дотянулся (Странно)")
		pass

func _check_vision():
	if target_player:
		_try_spot_player(target_player)

func _attack_player(player):
	if player.has_method("kill_player"):
		player.kill_player.rpc()
		target_player = null
		current_state = State.PATROL
		_get_new_patrol_location()
