extends Interactable

# --- НАСТРОЙКИ ---
@export_category("Door Settings")
@export var open_angle: float = 90.0
@export var close_angle: float = 0.0
@export var speed: float = 2.0

# Если пустое — дверь открыта. Если написано (например "Red Key") — заперта.
@export var required_key_name: String = "" 

# Звуки (можно перетащить в инспекторе)
@export var sound_open: AudioStream
@export var sound_close: AudioStream
@export var sound_locked: AudioStream

# --- СОСТОЯНИЕ ---
# is_locked теперь зависит от того, задано ли имя ключа
@export var is_open: bool = false:
	set(value):
		is_open = value
		_update_door_visuals()

# Отдельная переменная для замка (синхронизируем её!)
@export var is_locked: bool = false 

@onready var audio_player = $AudioStreamPlayer3D # Добавь эту ноду в сцену двери!

func _ready():
	# Если при старте задано имя ключа, значит дверь заперта
	if required_key_name != "":
		is_locked = true
	_update_door_visuals()

# --- ЛОГИКА СЕРВЕРА ---
@rpc("any_peer", "call_local", "reliable")
func _server_interact():
	if not multiplayer.is_server(): return
	
	# Узнаем, кто стучится
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	# 1. Если дверь УЖЕ открыта — просто закрываем
	if is_open:
		is_open = false
		play_sound.rpc("close")
		return

	# 2. Если дверь ЗАПЕРТА
	if is_locked:
		# Ищем игрока и его инвентарь
		var player = get_tree().current_scene.find_child(str(sender_id), true, false)
		if player:
			var inventory = player.get_node_or_null("Inventory")
			if inventory:
				# Проверяем, есть ли ключ
				if inventory.has_item(required_key_name):
					# УРА! Ключ есть.
					print("Игрок ", sender_id, " открыл замок ключом: ", required_key_name)
					is_locked = false # Отпираем навсегда
					is_open = true    # Открываем
					play_sound.rpc("unlock") # Звук открытия замка
					
					# (Опционально) Удалить ключ после использования?
					# inventory.remove_item_by_name(required_key_name) 
				else:
					# Ключа нет
					print("Дверь заперта! Нужен: ", required_key_name)
					play_sound.rpc("locked")
			else:
				print("Ошибка: Нет инвентаря")
		return

	# 3. Если дверь НЕ заперта и НЕ открыта — открываем
	is_open = true
	play_sound.rpc("open")

# --- ВИЗУАЛ И ЗВУКИ ---
func _update_door_visuals():
	var target = deg_to_rad(open_angle if is_open else close_angle)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation:y", target, 0.5)

@rpc("call_local")
func play_sound(type: String):
	if not audio_player: return
	
	match type:
		"open": audio_player.stream = sound_open
		"close": audio_player.stream = sound_close
		"locked": audio_player.stream = sound_locked
		"unlock": audio_player.stream = sound_open # Или отдельный звук щелчка
	
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()
