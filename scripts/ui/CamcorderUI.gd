extends CanvasLayer

# Ссылки на узлы (убедитесь, что имена совпадают в дереве сцены)
@onready var date_label: Label = $DateLabel
@onready var timer_label: Label = $TimerLabel

# --- Настройки ---
@export_group("Camcorder Settings")
@export var use_real_year: bool = false   # Если false, будет использоваться fake_year
@export var fake_year: int = 1996         # Год для атмосферы Backrooms
@export var show_seconds_blink: bool = true # Мигание двоеточия

var start_time_msec: int = 0
var month_names: Array[String] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

func _ready() -> void:
	# Запоминаем время старта уровня
	start_time_msec = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	update_status_display()

func update_status_display() -> void:
	var current_sys_time = Time.get_datetime_dict_from_system()
	
	# --- 1. Обработка Даты и Времени (Правый нижний угол) ---
	var year = current_sys_time.year if use_real_year else fake_year
	var month_str = month_names[current_sys_time.month - 1]
	
	# Конвертация в 12-часовой формат (AM/PM)
	var hour = current_sys_time.hour
	var period = "AM"
	if hour >= 12:
		period = "PM"
		if hour > 12:
			hour -= 12
	if hour == 0:
		hour = 12
	
	# Эффект мигания двоеточия (каждые 0.5 секунды)
	var separator = ":"
	if show_seconds_blink:
		# Time.get_ticks_msec() % 1000 < 500 дает мигание раз в секунду
		if (Time.get_ticks_msec() % 1000) > 500:
			separator = " "
	
	# Формат: DEC 25 1996   10:35 PM
	date_label.text = "%s %02d %d\n%02d%s%02d %s" % [
		month_str, 
		current_sys_time.day, 
		year,
		hour, 
		separator, 
		current_sys_time.minute, 
		period
	]

	# --- 2. Обработка Таймера (Левый нижний угол или верх) ---
	# Показываем, сколько игрок находится на уровне
	var elapsed_msec = Time.get_ticks_msec() - start_time_msec
	var total_seconds = elapsed_msec / 1000
	
	var m = total_seconds / 60
	var s = total_seconds % 60
	var ms = (elapsed_msec % 1000) / 10 # Сотые доли секунды (как кадры)
	
	# SP (Standard Play) - классический индикатор записи
	timer_label.text = "SP 0:%02d:%02d:%02d" % [m, s, ms]
