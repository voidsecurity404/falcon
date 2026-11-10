#version 440
// The desktop's sound looks drawn in one pass by components/SpectrumField.qml: ribbon, segments,
// aura, ring and orb. The 36 bands come in as nine vec4 (`b0` to `b8`), already smoothed, 0 to 1.
// Rebuild after a change: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o spectrum.frag.qsb spectrum.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 b4;
    vec4 b5;
    vec4 b6;
    vec4 b7;
    vec4 b8;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec2 size;
    float look;
    float time;
    float alpha;
    float mirrored;
    float bars;
    float bass;
};

const float PI = 3.14159265;
float L[36];

void fill() {
    vec4 parts[9] = vec4[9](b0, b1, b2, b3, b4, b5, b6, b7, b8);
    for (int i = 0; i < 9; i++) {
        L[i * 4] = parts[i].x;
        L[i * 4 + 1] = parts[i].y;
        L[i * 4 + 2] = parts[i].z;
        L[i * 4 + 3] = parts[i].w;
    }
}

// The level of the bands at `x`, 0 for the lowest notes to 1 for the highest.
float band(float x) {
    x = clamp(x, 0.0, 1.0);
    float at = x * 35.0;
    int low = int(floor(at));
    int high = min(35, low + 1);
    float t = (1.0 - cos((at - float(low)) * PI)) * 0.5;
    return mix(L[low], L[high], t);
}

// The level at `x` across a strip, from the middle outward when mirrored.
float level(float x) {
    x = clamp(x, 0.0, 1.0);
    return band(mirrored > 0.5 ? abs(x * 2.0 - 1.0) : x);
}

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// Three see-through waves out of phase, lit along their tops.
vec4 ribbon(vec2 uv) {
    float y = 1.0 - uv.y;
    vec4 c = vec4(0.0);
    vec3 cols[3] = vec3[3](color1.rgb, color2.rgb, color3.rgb);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float sway = 0.75 + 0.25 * sin(uv.x * (5.0 + fi * 2.0) + time * (0.9 + fi * 0.35) + fi * 2.1);
        float h = level(uv.x + 0.015 * sin(time * 0.7 + fi)) * sway * (1.0 - fi * 0.18) + 0.015;
        float aa = 1.5 / size.y;
        float inside = 1.0 - smoothstep(h - aa, h + aa, y);
        float edge = exp(-abs(y - h) * size.y / 2.5);
        float body = inside * mix(0.15, 0.75, y / max(h, 0.001));
        float a = (body * 0.55 + edge * 0.9) * (0.75 - fi * 0.15);
        c.rgb += cols[i] * a;
        c.a += a;
    }
    c.a = min(c.a, 1.0);
    return c * alpha;
}

// A meter of separate cells in each column.
vec4 segments(vec2 uv) {
    float columns = bars;
    float colW = size.x / columns;
    float px = uv.x * size.x;
    float col = floor(px / colW);
    float inCol = px - col * colW;
    float gapX = max(2.0, colW * 0.22);
    if (inCol < gapX * 0.5 || inCol > colW - gapX * 0.5)
        return vec4(0.0);
    float cellH = 9.0;
    float gapY = 3.0;
    float py = (1.0 - uv.y) * size.y;
    float cell = floor(py / (cellH + gapY));
    if (py - cell * (cellH + gapY) > cellH)
        return vec4(0.0);
    float lit = level((col + 0.5) / columns) * size.y;
    float top = (cell + 1.0) * (cellH + gapY);
    if (cell * (cellH + gapY) > lit)
        return vec4(0.0);
    float t = clamp(py / size.y, 0.0, 1.0);
    vec3 col3 = mix(color1.rgb, color2.rgb, smoothstep(0.35, 0.95, t));
    float a = mix(0.65, 1.0, t) * (top <= lit ? 1.0 : 0.6);
    return vec4(col3 * a, a) * alpha;
}

// Light along the edges of the screen, flowing slowly and rising with the sound. Each edge glows
// on its own and the four are added, so the corners have no seams. Along the edges `s` runs from
// the bottom middle (low notes) round both sides to the top middle (high notes).
float edgeGlow(float d, float s, out vec3 tone) {
    float lv = band(s);
    float flow = noise(s * 14.0 - time * 0.45) * 0.6 + noise(s * 31.0 + time * 0.3) * 0.4;
    float reach = mix(10.0, 95.0, clamp(lv * 1.1 + bass * 0.2, 0.0, 1.0)) * (0.6 + 0.8 * flow);
    float glow = exp(-pow(d / max(reach, 1.0), 1.5));
    float core = exp(-d / 2.5) * 0.5;
    tone = mix(mix(color1.rgb, color2.rgb, smoothstep(0.0, 0.6, s)), color3.rgb, smoothstep(0.5, 1.0, s + 0.15 * sin(time * 0.5)));
    return (glow * (0.2 + 0.8 * lv) + core * lv) * 0.95;
}

vec4 aura(vec2 uv) {
    vec2 p = uv * size;
    float mid = size.x * 0.5;
    float total = size.x + size.y;
    vec3 t1;
    vec3 t2;
    vec3 t3;
    vec3 t4;
    float a1 = edgeGlow(size.y - p.y, abs(p.x - mid) / total, t1);
    float a2 = edgeGlow(p.y, 1.0 - abs(p.x - mid) / total, t2);
    float a3 = edgeGlow(p.x, (mid + size.y - p.y) / total, t3);
    float a4 = edgeGlow(size.x - p.x, (mid + size.y - p.y) / total, t4);
    float sum = a1 + a2 + a3 + a4;
    vec3 rgb = (t1 * a1 + t2 * a2 + t3 * a3 + t4 * a4) / max(sum, 0.0001);
    float a = clamp(sum, 0.0, 1.0);
    return vec4(rgb * a, a) * alpha;
}

// Rounded bars around a ring that swells with the bass.
vec4 ring(vec2 uv) {
    vec2 p = (uv - 0.5) * size / min(size.x, size.y);
    float r = length(p);
    float ang = atan(p.x, -p.y);
    float inner = 0.24 + 0.035 * bass;
    float count = bars;
    float cellAng = 2.0 * PI / count;
    float idx = floor((ang + PI) / cellAng);
    float centerAng = (idx + 0.5) * cellAng - PI;
    float lv = band(abs(centerAng) / PI);
    float len = 0.02 + lv * 0.22;
    // Distance to the bar as a capsule along its own direction.
    vec2 dir = vec2(sin(centerAng), -cos(centerAng));
    vec2 a = dir * (inner + 0.012);
    vec2 b = dir * (inner + 0.012 + len);
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float width = 0.42 * inner * cellAng;
    float dist = length(pa - ba * h) - width;
    float px = 1.2 / min(size.x, size.y);
    float bar = 1.0 - smoothstep(-px, px, dist);
    float circle = exp(-abs(r - inner) / 0.004) * (0.35 + 0.65 * bass);
    vec3 col3 = mix(color1.rgb, color2.rgb, smoothstep(0.0, 1.0, h * lv * 1.6));
    float aBar = bar * mix(0.55, 1.0, h);
    float total = clamp(aBar + circle * 0.8, 0.0, 1.0);
    vec3 rgb = (col3 * aBar + color3.rgb * circle * 0.8);
    return vec4(rgb, total) * alpha;
}

// A glass sphere: a faint body, a rim that wobbles with the sound, ripples inside.
vec4 orb(vec2 uv) {
    vec2 p = (uv - 0.5) * size / min(size.x, size.y);
    float r = length(p);
    float ang = atan(p.x, -p.y);
    float lv = band(abs(ang) / PI);
    float radius = 0.3 + 0.03 * bass;
    float rim = radius * (1.0 + 0.09 * lv * sin(ang * 3.0 + time * 1.4) + 0.05 * lv);
    float px = 1.5 / min(size.x, size.y);
    float edge = exp(-abs(r - rim) / (0.006 + 0.01 * lv));
    float body = (1.0 - smoothstep(rim - px, rim + px, r)) * 0.12;
    float ripples = (1.0 - smoothstep(rim - px, rim, r)) * pow(max(0.0, sin(r * 70.0 - time * 3.0)), 6.0) * bass * 0.35;
    // A highlight in the upper left, as on glass.
    float shine = exp(-length(p - vec2(-0.32, -0.38) * radius) / (radius * 0.18)) * (1.0 - smoothstep(rim - px, rim, r)) * 0.35;
    vec3 col3 = mix(color1.rgb, color2.rgb, 0.5 + 0.5 * sin(ang + time * 0.4));
    float a = clamp(edge * (0.55 + 0.45 * lv) + body + ripples + shine, 0.0, 1.0);
    vec3 rgb = col3 * (edge * (0.55 + 0.45 * lv) + body + ripples) + vec3(1.0) * shine;
    return vec4(rgb, a) * alpha;
}

void main() {
    fill();
    int k = int(look + 0.5);
    vec4 c;
    if (k == 0) c = ribbon(qt_TexCoord0);
    else if (k == 1) c = segments(qt_TexCoord0);
    else if (k == 2) c = aura(qt_TexCoord0);
    else if (k == 3) c = ring(qt_TexCoord0);
    else c = orb(qt_TexCoord0);
    fragColor = c * qt_Opacity;
}
