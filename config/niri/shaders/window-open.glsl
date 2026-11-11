// Window opening animations, picked in Settings -> Animations (windows.openAnimation).
// bin/falcon-apply puts this whole file into `window-open { custom-shader }` with an
// open_color() that calls fo_pick() with the chosen number, and the curve set to linear, so
// every easing happens here. The Settings preview (quickshell shaders/winopen.frag) is built
// from this same file by config/niri/shaders/build-preview.sh, so it shows exactly the same thing.
// Written for GLSL ES 1.00 (niri), which also compiles as GLSL 440 for the preview.
// Inputs: g = position in the window's geometry (0 to 1 inside the window, outside it around it),
// s = window size in logical pixels. niri_clamped_progress goes 0 to 1 at an even pace.

float fo_clamp01(float x) {
    return clamp(x, 0.0, 1.0);
}

float fo_out3(float x) {
    float y = 1.0 - fo_clamp01(x);
    return 1.0 - y * y * y;
}

float fo_out5(float x) {
    float y = 1.0 - fo_clamp01(x);
    return 1.0 - y * y * y * y * y;
}

float fo_expo(float x) {
    x = fo_clamp01(x);
    return x >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
}

// Ease out with a small overshoot past 1.
float fo_back(float x) {
    x = fo_clamp01(x);
    float c = 1.9;
    float y = x - 1.0;
    return 1.0 + (c + 1.0) * y * y * y + c * y * y;
}

// Falls and bounces twice, settling at 1.
float fo_bounce(float x) {
    x = fo_clamp01(x);
    if (x < 0.5)
        return 4.0 * x * x;
    if (x < 0.8) {
        float y = (x - 0.65) / 0.15;
        return 1.0 - 0.12 * (1.0 - y * y);
    }
    float y = (x - 0.9) / 0.1;
    return 1.0 - 0.03 * (1.0 - y * y);
}

float fo_hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + niri_random_seed * 17.0);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float fo_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fo_hash(i);
    float b = fo_hash(i + vec2(1.0, 0.0));
    float c = fo_hash(i + vec2(0.0, 1.0));
    float d = fo_hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The window's color at a geometry position, nothing outside its texture.
vec4 fo_take(vec2 g) {
    vec3 t = niri_geo_to_tex * vec3(g, 1.0);
    if (t.x < 0.0 || t.x > 1.0 || t.y < 0.0 || t.y > 1.0)
        return vec4(0.0);
    return texture2D(niri_tex, t.st);
}

// Scales the window around a point of it (0.5, 0.5 is the middle).
vec4 fo_scaled(vec2 g, vec2 scale, vec2 around) {
    return fo_take((g - around) / scale + around);
}

// 0 Standard: niri's own opening, the window grows from half size and fades in.
vec4 fo_standard(vec2 g, vec2 s, float p) {
    float e = fo_expo(p);
    return fo_scaled(g, vec2(0.5 + e * 0.5), vec2(0.5)) * e;
}

// 1 Fade: only the transparency changes.
vec4 fo_fade(vec2 g, vec2 s, float p) {
    return fo_take(g) * fo_out3(p);
}

// 2 Pop: grows from 60% and springs a little past full size.
vec4 fo_pop(vec2 g, vec2 s, float p) {
    float k = 0.6 + 0.4 * fo_back(p);
    return fo_scaled(g, vec2(k), vec2(0.5)) * fo_clamp01(p * 3.0);
}

// 3 Rise: comes up from below.
vec4 fo_rise(vec2 g, vec2 s, float p) {
    float e = fo_out5(p);
    float lift = (1.0 - e) * 160.0 / s.y;
    return fo_take(g - vec2(0.0, lift)) * fo_out3(p * 1.4);
}

// 4 Drop: falls from above and bounces.
vec4 fo_drop(vec2 g, vec2 s, float p) {
    float e = fo_bounce(p);
    float fall = (1.0 - e) * 0.45;
    return fo_take(g + vec2(0.0, fall)) * fo_clamp01(p * 4.0);
}

// 5 Zoom: comes from bigger than the screen toward its place.
vec4 fo_zoom(vec2 g, vec2 s, float p) {
    float e = fo_out5(p);
    return fo_scaled(g, vec2(1.0 + (1.0 - e) * 0.35), vec2(0.5)) * fo_out3(p * 1.2);
}

// 6 Unfold: a thin line opens sideways, then downward and upward, like an old TV.
vec4 fo_unfold(vec2 g, vec2 s, float p) {
    float w = fo_out3(p / 0.45);
    float h = fo_out5((p - 0.3) / 0.7);
    vec2 k = vec2(max(w, 0.001), max(0.006 + h * 0.994, 0.001));
    float bright = 1.0 + (1.0 - h) * 0.8;
    vec4 c = fo_scaled(g, k, vec2(0.5));
    return vec4(min(c.rgb * bright, vec3(c.a)), c.a) * fo_clamp01(p * 5.0);
}

// 7 Flip: turns in around its vertical middle, in perspective.
vec4 fo_flip(vec2 g, vec2 s, float p) {
    float a = (1.0 - fo_back(p)) * 1.45;
    float d = max(s.x, s.y) * 1.6;
    vec2 q = (g - 0.5) * s;
    float den = d * cos(a) - q.x * sin(a);
    if (den <= 0.0)
        return vec4(0.0);
    float x = q.x * d / den;
    float z = x * sin(a);
    float y = q.y * (d + z) / d;
    vec4 c = fo_take(vec2(x, y) / s + 0.5);
    float shade = 1.0 - 0.45 * abs(sin(a));
    return vec4(c.rgb * shade, c.a) * fo_clamp01(p * 3.0);
}

// 8 Circle: shows through a circle growing from the middle.
vec4 fo_circle(vec2 g, vec2 s, float p) {
    float e = fo_out3(p);
    vec2 q = (g - 0.5) * s;
    float r = e * length(s) * 0.52;
    float edge = 1.0 - smoothstep(r - 18.0, r, length(q));
    return fo_scaled(g, vec2(0.92 + 0.08 * e), vec2(0.5)) * edge;
}

// 9 Pixels: starts as big squares that get finer.
vec4 fo_pixels(vec2 g, vec2 s, float p) {
    float e = fo_out3(p);
    float cell = mix(64.0, 1.0, e);
    if (cell > 1.5) {
        vec2 c = cell / s;
        g = (floor(g / c) + 0.5) * c;
    }
    return fo_take(g) * fo_clamp01(p * 2.5);
}

// 10 Glitch: torn slices and split colors that calm down.
vec4 fo_glitch(vec2 g, vec2 s, float p) {
    float k = 1.0 - fo_out3(p);
    float tick = floor(p * 14.0);
    float slice = floor(g.y * 22.0);
    float r = fo_hash(vec2(slice, tick));
    float shift = (r - 0.5) * 0.22 * k * step(0.45, r);
    float split = 0.025 * k;
    vec4 c = fo_take(g + vec2(shift, 0.0));
    vec4 cr = fo_take(g + vec2(shift + split, 0.0));
    vec4 cb = fo_take(g + vec2(shift - split, 0.0));
    vec4 col = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));
    col.rgb = min(col.rgb, vec3(col.a));
    float flicker = 1.0 - k * 0.5 * step(0.8, fo_hash(vec2(tick, 3.0)));
    return col * fo_clamp01(p * 2.2) * flicker;
}

// 11 Dissolve: appears through soft noise with a bright edge.
vec4 fo_dissolve(vec2 g, vec2 s, float p) {
    float e = fo_out3(p) * 1.2;
    float n = fo_noise(g * s / 26.0) * 0.7 + fo_noise(g * s / 7.0) * 0.3;
    float shown = smoothstep(n - 0.06, n, e - 0.1);
    float edge = smoothstep(n - 0.12, n, e) - shown;
    vec4 c = fo_take(g);
    vec3 glow = vec3(1.0) * edge * 0.9 * c.a;
    return vec4(c.rgb * shown + glow, c.a * max(shown, edge * 0.9));
}

// 12 Blinds: horizontal slats open one after another from the top.
vec4 fo_blinds(vec2 g, vec2 s, float p) {
    float rows = 10.0;
    float row = floor(g.y * rows);
    float local = fract(g.y * rows);
    float start = row / rows * 0.45;
    float o = fo_out3((p - start) / 0.55);
    float shown = step(abs(local - 0.5), o * 0.5 + 0.001);
    return fo_take(g) * shown * (0.5 + 0.5 * o);
}

// 13 Swing: hangs from its top edge and swings down into place.
vec4 fo_swing(vec2 g, vec2 s, float p) {
    float a = (1.0 - fo_back(p)) * 1.35;
    float d = max(s.x, s.y) * 1.6;
    vec2 q = vec2((g.x - 0.5) * s.x, g.y * s.y);
    float den = d * cos(a) - q.y * sin(a);
    if (den <= 0.0)
        return vec4(0.0);
    float y = q.y * d / den;
    float z = y * sin(a);
    float x = q.x * (d + z) / d;
    vec4 c = fo_take(vec2(x / s.x + 0.5, y / s.y));
    float shade = 1.0 - 0.4 * abs(sin(a));
    return vec4(c.rgb * shade, c.a) * fo_clamp01(p * 3.0);
}

// Number of looks above; 14 in settings means a random one each time.
vec4 fo_pick(float n, vec2 g, vec2 s, float p) {
    if (n < 0.5) return fo_standard(g, s, p);
    if (n < 1.5) return fo_fade(g, s, p);
    if (n < 2.5) return fo_pop(g, s, p);
    if (n < 3.5) return fo_rise(g, s, p);
    if (n < 4.5) return fo_drop(g, s, p);
    if (n < 5.5) return fo_zoom(g, s, p);
    if (n < 6.5) return fo_unfold(g, s, p);
    if (n < 7.5) return fo_flip(g, s, p);
    if (n < 8.5) return fo_circle(g, s, p);
    if (n < 9.5) return fo_pixels(g, s, p);
    if (n < 10.5) return fo_glitch(g, s, p);
    if (n < 11.5) return fo_dissolve(g, s, p);
    if (n < 12.5) return fo_blinds(g, s, p);
    return fo_swing(g, s, p);
}
