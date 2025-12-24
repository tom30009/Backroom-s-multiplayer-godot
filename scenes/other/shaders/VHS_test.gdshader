shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform float color_displacement : hint_range(0.0, 1.0) = 0.3; // Очень мягкая аберрация
uniform float grain_intensity : hint_range(0.0, 0.05) = 0.01; // Почти невидимый шум


uniform float distortion : hint_range(0.0, 0.05) = 0.005;     // Едва заметный изгиб
uniform float scanline_opacity : hint_range(0.0, 0.2) = 0.05; // Еле видные линии
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.2; // Только по самым углам


uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // По умолчанию белый

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    // Минимальный коэффициент искривления
    uv.x *= 1.0 + pow((abs(uv.y) * distortion), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) * distortion), 2.0);
    uv  = (uv / 2.0) + 0.5;
    return uv;
}

void fragment() {
    vec2 uv = curve(SCREEN_UV);
    
    // Проверка границ
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // Мягкий сдвиг цветов
        float shift = color_displacement / 1000.0;
        float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
        float g = texture(SCREEN_TEXTURE, uv).g;
        float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
        
        vec3 color = vec3(r, g, b);

        // Тончайший шум
        color += (random(uv + TIME) - 0.5) * grain_intensity;

        // Очень мягкие сканирующие линии
        color -= (sin(uv.y * 900.0) * scanline_opacity) * 0.1;

        // Легкая виньетка
        float dist = distance(uv, vec2(0.5));
        color *= smoothstep(0.9, 0.9 - vignette_softness, dist);

        COLOR = vec4(color * tint.rgb * brightness, 1.0);
    }
}