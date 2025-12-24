extends Interactable

# Угол открытия (в градусах)
@export var open_angle: float = 90.0
@export var close_angle: float = 0.0
@export var speed: float = 2.0

# Переменная состояния. Если меняется - срабатывает сеттер.
@export var is_open: bool = false:
	set(value):
		is_open = value
		_update_door_visuals()

func _ready():
	# При старте (или подключении) дверь сразу встает в нужное положение
	_update_door_visuals()

# Переопределяем метод сервера из базового класса
@rpc("any_peer", "call_local", "reliable")
func _server_interact():
	# Эта логика выполняется только на сервере (ID 1)
	if multiplayer.is_server():
		# Меняем переменную. Благодаря MultiplayerSynchronizer 
		# это изменение улетит всем клиентам.
		is_open = not is_open

# Функция анимации (выполняется у всех локально при смене переменной)
func _update_door_visuals():
	var target_rotation_y = deg_to_rad(open_angle if is_open else close_angle)
	
	# Используем Tween для плавности (это мощная фишка Godot 4)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Вращаем саму ноду двери (self)
	tween.tween_property(self, "rotation:y", target_rotation_y, 0.5)