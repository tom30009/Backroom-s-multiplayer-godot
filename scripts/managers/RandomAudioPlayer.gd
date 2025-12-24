class_name RandomAudioPlayer extends AudioStreamPlayer3D

@export_category("Random Settings")
@export var sound_library: Array[AudioStream] # Сюда перетащим кучу звуков
@export var min_wait_time: float = 5.0
@export var max_wait_time: float = 15.0
@export var play_immediately: bool = false # Играть ли сразу при старте?

var timer: Timer

func _ready():
	# Создаем таймер кодом
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	if play_immediately:
		_play_random_sound()
	else:
		_start_timer()

func _start_timer():
	var time = randf_range(min_wait_time, max_wait_time)
	timer.start(time)

func _on_timer_timeout():
	_play_random_sound()

func _play_random_sound():
	if sound_library.size() > 0:
		# Выбираем случайный звук
		stream = sound_library.pick_random()
		
		# Меняем высоту тона для разнообразия (чуть ниже или выше)
		pitch_scale = randf_range(0.9, 1.1)
		
		play()
		
		# Ждем, пока звук доиграет, плюс пауза, потом снова запускаем таймер
		# (Если звук длинный, лучше ждать сигнала finished)
	else:
		print("В RandomAudioPlayer нет звуков!")
		
	# Запускаем таймер для следующего раза
	_start_timer()
