extends Light3D

# Настройки мигания
@export var min_energy = 0.5
@export var max_energy = 2.0
@export var flicker_chance = 0.1 # Шанс выключиться полностью (10%)

var noise = FastNoiseLite.new()
var time_passed = 0.0

func _ready():
	# Настраиваем шум для плавного, но хаотичного изменения
	noise.seed = randi()
	noise.frequency = 10.0 # Как быстро меняется свет

func _process(delta):
	time_passed += delta * 50.0 # Скорость мерцания
	
	# Получаем значение шума (-1..1) и переводим в (0..1)
	var noise_value = (noise.get_noise_1d(time_passed) + 1.0) / 2.0
	
	# Случайное резкое выключение (эффект плохой проводки)
	if randf() < flicker_chance * delta * 10.0:
		light_energy = 0.0
		# Издать звук треска (опционально)
	else:
		# Обычное дрожание яркости
		light_energy = lerp(min_energy, max_energy, noise_value)
