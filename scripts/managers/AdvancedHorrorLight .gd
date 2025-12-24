class_name AdvancedHorrorLight extends Light3D

# --- ГЛАВНЫЕ НАСТРОЙКИ ---
enum Style {
	FLUORESCENT, # Офисная лампа (гудит и иногда гаснет)
	BROKEN,      # Сломана (почти всегда выключена, иногда вспыхивает)
	PULSE,       # Медленное дыхание (для атмосферы)
	STROBE,      # Стробоскоп (резко вкл/выкл)
	CANDLE       # Свеча/Костер (мягкое дрожание)
}

@export_category("Main Settings")
@export var style: Style = Style.FLUORESCENT
@export var base_energy: float = 1.5      # Нормальная яркость
@export var active: bool = true           # Можно выключить скриптом

@export_category("Flicker Details")
@export_range(0.1, 50.0) var speed: float = 15.0       # Скорость изменения
@export_range(0.0, 1.0) var stability: float = 0.7     # 1.0 = горит ровно, 0.0 = эпилепсия
@export_range(0.0, 1.0) var off_chance: float = 0.05   # Шанс полностью погаснуть на мгновение

@export_category("Audio (Optional)")
@export var audio_player: AudioStreamPlayer3D # Ссылка на звук (треск/гул)
@export var sync_sound_with_light: bool = true # Если свет погас - звук выкл

# Внутренние переменные
var noise = FastNoiseLite.new()
var time_pointer = 0.0
var target_energy = 0.0

func _ready():
	randomize()
	noise.seed = randi()
	noise.frequency = 0.5 # Частота самого шума
	
	# Сразу проверяем, есть ли звук
	if audio_player and not audio_player.playing and active:
		audio_player.play()

func _process(delta):
	if not active:
		light_energy = 0.0
		if audio_player and sync_sound_with_light: audio_player.stop()
		return

	time_pointer += delta * speed
	
	match style:
		Style.FLUORESCENT:
			_process_fluorescent()
		Style.BROKEN:
			_process_broken()
		Style.PULSE:
			_process_pulse()
		Style.STROBE:
			_process_strobe()
		Style.CANDLE:
			_process_candle()
	
	# Синхронизация звука (если свет погас совсем - звук прерывается)
	if audio_player and sync_sound_with_light:
		if light_energy <= 0.1 and audio_player.playing:
			audio_player.stream_paused = true
		elif light_energy > 0.1 and audio_player.stream_paused:
			audio_player.stream_paused = false

# --- ЛОГИКА РЕЖИМОВ ---

# 1. Офисная лампа: Шум Перлина + редкие провалы
func _process_fluorescent():
	var noise_val = noise.get_noise_1d(time_pointer) # от -1 до 1
	# Превращаем шум в легкое дрожание (например от 0.8 до 1.2)
	var flicker = 1.0 + (noise_val * (1.0 - stability))
	
	# Резкий провал (плохой контакт)
	if randf() < off_chance * 0.1: # Шанс редкий
		light_energy = 0.0
	else:
		light_energy = base_energy * flicker

# 2. Сломанная: Почти всегда 0, иногда вспышка
func _process_broken():
	# Шанс включиться зависит от stability (чем меньше stability, тем чаще вспышки)
	if randf() > stability: 
		light_energy = base_energy * randf_range(0.5, 1.5)
	else:
		light_energy = 0.0

# 3. Пульс: Синусоида (как дыхание монстра или аварийка)
func _process_pulse():
	# speed здесь влияет на скорость пульсации
	var wave = (sin(time_pointer) + 1.0) / 2.0 # от 0 до 1
	light_energy = base_energy * wave

# 4. Стробоскоп: Жесткое ВКЛ/ВЫКЛ без полутонов
func _process_strobe():
	# Используем time_pointer как таймер
	if sin(time_pointer) > 0.0:
		light_energy = base_energy
	else:
		light_energy = 0.0

# 5. Свеча: Очень мягкий шум, никогда не гаснет полностью
func _process_candle():
	var noise_val = noise.get_noise_1d(time_pointer)
	# Дрожит в диапазоне 80% - 120%
	light_energy = base_energy * (0.8 + noise_val * 0.4)
