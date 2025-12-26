shader_type canvas_item;

// Насколько сильно игрок устал (0.0 - бодр, 1.0 - задыхается)
uniform float intensity : hint_range(0.0, 1.0);
// Цвет виньетки (по умолчанию черный, можно сделать темно-красным для крови)
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// Получаем координаты от центра (0.5, 0.5)
	vec2 uv = UV - vec2(0.5);

	// Считаем длину вектора (расстояние от центра)
	float dist = length(uv);

	// --- МАГИЯ КРАСОТЫ ---
	// smoothstep делает переход очень мягким.
	// 0.2 - начало затемнения, 0.8 - полная темнота в углах.
	// Мы умножаем dist на intensity, чтобы круг сужался, когда мы устаем.
	float vignette = smoothstep(0.4, 1.2 - (intensity * 0.7), dist * 1.5);

	// Добавляем легкую пульсацию, если совсем устали (> 0.8)
	if (intensity > 0.8) {
		float pulse = sin(TIME * 5.0) * 0.05;
		vignette += pulse;
	}

	// Применяем цвет и прозрачность
	COLOR = vignette_color;
	COLOR.a = vignette * intensity; // Чем больше intensity, тем гуще тьма
}