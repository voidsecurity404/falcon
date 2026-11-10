#version 440
// The wallpaper's arrival in modules/Parallax.qml: `from` is the picture on screen, `to` the new
// one, `progress` goes 0 to 1 (already eased). One shader holds every effect, picked by `effect`.
// Rebuild after a change: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o wallpaper.frag.qsb wallpaper.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float effect;
    float seed;
    vec2 size;
    vec2 origin;
};

layout(binding = 1) uniform sampler2D from;
layout(binding = 2) uniform sampler2D to;

const float PI = 3.14159265;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec4 A(vec2 uv) { return texture(from, clamp(uv, 0.0, 1.0)); }
vec4 B(vec2 uv) { return texture(to, clamp(uv, 0.0, 1.0)); }

// One pixel of soft edge, so hard edges are not jagged.
float px() { return 1.0 / max(size.x, 1.0); }

vec4 fade(vec2 uv, float p) {
    return mix(A(uv), B(uv), p);
}

// A circle opening from `origin`, as awww's grow.
vec4 grow(vec2 uv, float p) {
    vec2 o = origin * size;
    vec2 here = uv * size;
    float reach = 0.0;
    reach = max(reach, length(o - vec2(0.0, 0.0)));
    reach = max(reach, length(o - vec2(size.x, 0.0)));
    reach = max(reach, length(o - vec2(0.0, size.y)));
    reach = max(reach, length(o - size));
    float r = p * (reach + 2.0);
    float m = 1.0 - smoothstep(r - 1.0, r + 1.0, length(here - o));
    return mix(A(uv), B(uv), m);
}

vec4 wipe(vec2 uv, float p) {
    float e = p * (1.0 + 2.0 * px());
    float m = 1.0 - smoothstep(e - 2.0 * px(), e, uv.x);
    return mix(A(uv), B(uv), m);
}

// A wipe whose edge moves like a wave.
vec4 wave(vec2 uv, float p) {
    float w = 0.06;
    float e = p * (1.0 + 2.0 * w) - w + w * sin(uv.y * 14.0 + p * 9.0) * 0.8 + w * 0.4 * sin(uv.y * 31.0 - p * 5.0);
    float m = 1.0 - smoothstep(e - 3.0 * px(), e, uv.x);
    return mix(A(uv), B(uv), m);
}

// Grains of the new picture appear at random.
vec4 dissolve(vec2 uv, float p) {
    float n = 0.65 * hash(floor(uv * size / 3.0)) + 0.35 * noise(uv * 9.0);
    float m = smoothstep(n - 0.04, n + 0.04, p * 1.08 - 0.04);
    return mix(A(uv), B(uv), m);
}

// Coarser and coarser pixels, the swap in the middle, then sharp again.
vec4 pixels(vec2 uv, float p) {
    float coarse = 1.0 - abs(2.0 * p - 1.0);
    float cell = max(1.0, floor(coarse * coarse * 70.0));
    vec2 count = size / cell;
    vec2 q = (floor(uv * count) + 0.5) / count;
    return mix(A(q), B(q), smoothstep(0.42, 0.58, p));
}

// Squares grow in each tile, the tiles in random order.
vec4 blocks(vec2 uv, float p) {
    vec2 count = vec2(16.0, 16.0 * size.y / size.x);
    vec2 tile = floor(uv * count);
    vec2 local = fract(uv * count);
    float delay = hash(tile) * 0.6;
    float t = clamp((p - delay) / 0.4, 0.0, 1.0);
    vec2 d = abs(local - 0.5) * 2.0;
    float m = 1.0 - smoothstep(t - 0.04, t, max(d.x, d.y));
    return mix(A(uv), B(uv), t >= 1.0 ? 1.0 : m);
}

// The old picture breaks into shards that shrink and fall away.
vec2 seedOf(vec2 cell) {
    return cell + 0.15 + 0.7 * vec2(hash(cell), hash(cell + 17.3));
}

vec2 nearestCell(vec2 q) {
    vec2 base = floor(q);
    vec2 best = base;
    float bestD = 1e9;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 c = base + vec2(float(x), float(y));
            float d = length(q - seedOf(c));
            if (d < bestD) {
                bestD = d;
                best = c;
            }
        }
    }
    return best;
}

vec4 shatter(vec2 uv, float p) {
    float scale = 9.0;
    vec2 aspect = vec2(1.0, size.y / size.x);
    vec2 q = uv * aspect * scale;
    vec4 under = B(uv);
    // A shard reaching this pixel comes from its own cell or one nearby, falling from above.
    for (int y = 0; y >= -2; y--) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = floor(q) + vec2(float(x), float(y));
            vec2 c = seedOf(cell);
            float delay = 0.55 * hash(cell + 3.1) + 0.25 * (1.0 - c.y / (aspect.y * scale));
            float t = clamp((p - delay * 0.7) / 0.45, 0.0, 1.0);
            if (t >= 1.0)
                continue;
            float shrink = 1.0 - 0.75 * t;
            vec2 drop = vec2((hash(cell + 7.7) - 0.5) * 0.6 * t, 2.4 * t * t);
            vec2 back = c + (q - c - drop) / shrink;
            if (nearestCell(back) == cell) {
                vec2 src = back / scale / aspect;
                vec4 shard = A(src);
                shard.rgb *= 1.0 - 0.35 * t;
                return mix(shard, under, smoothstep(0.75, 1.0, t));
            }
        }
    }
    return under;
}

// Slices jump sideways, colors split, and each slice flips to the new picture on its own.
vec4 glitch(vec2 uv, float p) {
    float strength = sin(p * PI);
    float slices = 34.0;
    float row = floor(uv.y * slices);
    float tick = floor(p * 24.0);
    float jump = (hash(vec2(row, tick)) - 0.5) * 0.12 * strength * step(0.55, hash(vec2(tick, row * 0.37)));
    vec2 q = vec2(uv.x + jump, uv.y);
    float turn = 0.15 + 0.7 * hash(vec2(row, 9.0));
    bool newer = p > turn;
    float split = 0.012 * strength;
    vec4 c;
    if (newer)
        c = vec4(B(q + vec2(split, 0.0)).r, B(q).g, B(q - vec2(split, 0.0)).b, 1.0);
    else
        c = vec4(A(q + vec2(split, 0.0)).r, A(q).g, A(q - vec2(split, 0.0)).b, 1.0);
    // Blocks of noise flash during the strongest part.
    vec2 blockCell = floor(uv * vec2(24.0, 14.0));
    if (hash(blockCell + tick) > 1.0 - 0.06 * strength)
        c.rgb = mix(c.rgb, vec3(hash(blockCell * 1.7 + tick)), 0.6);
    return c;
}

// The old picture drips down in uneven columns, the new one shows above it.
vec4 melt(vec2 uv, float p) {
    float column = uv.x * size.x / 6.0;
    float r = 0.55 * noise(vec2(column * 0.08, 2.0)) + 0.45 * hash(vec2(floor(column), 5.0)) * 0.35;
    float dy = clamp(p * 1.6 - r * 0.6, 0.0, 1.0);
    dy = dy * dy * 1.05;
    if (uv.y < dy)
        return B(uv);
    vec4 old = A(vec2(uv.x, uv.y - dy));
    // A soft dark lip at the dripping edge.
    old.rgb *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.03, uv.y - dy)) * step(0.001, dy);
    return old;
}

// Rings run out from the middle and bend both pictures while they swap.
vec4 ripple(vec2 uv, float p) {
    vec2 aspect = vec2(size.x / size.y, 1.0);
    vec2 d = (uv - 0.5) * aspect;
    float dist = length(d);
    float strength = sin(p * PI) * 0.03;
    vec2 dir = dist > 0.0 ? d / dist : vec2(0.0);
    vec2 bend = dir * sin(dist * 42.0 - p * 22.0) * strength / aspect;
    // The new picture spreads out behind the first ring.
    float r = p * 1.35;
    float m = 1.0 - smoothstep(r - 0.18, r, dist);
    return mix(A(uv + bend), B(uv + bend), m);
}

// The old picture rushes forward and blurs into the new one, which settles from a little larger.
vec4 zoom(vec2 uv, float p) {
    vec2 c = uv - 0.5;
    float aZoom = 1.0 + 0.45 * p * p;
    float bZoom = 1.0 + 0.25 * (1.0 - p) * (1.0 - p);
    float blur = sin(p * PI) * 0.06;
    vec4 a = vec4(0.0);
    vec4 b = vec4(0.0);
    for (int i = 0; i < 8; i++) {
        float k = 1.0 - blur * float(i) / 8.0;
        a += A(0.5 + c / aZoom * k);
        b += B(0.5 + c / bZoom * k);
    }
    return mix(a / 8.0, b / 8.0, smoothstep(0.3, 0.7, p));
}

// A whirl around the middle carries the old picture away.
vec4 swirl(vec2 uv, float p) {
    vec2 aspect = vec2(size.x / size.y, 1.0);
    vec2 d = (uv - 0.5) * aspect;
    float dist = length(d);
    float angle = sin(p * PI) * 5.0 * pow(max(0.0, 1.0 - dist / 0.95), 2.0);
    float s = sin(angle);
    float co = cos(angle);
    vec2 turned = vec2(d.x * co - d.y * s, d.x * s + d.y * co) / aspect + 0.5;
    return mix(A(turned), B(turned), smoothstep(0.35, 0.65, p));
}

// Slats turn, top to bottom.
vec4 blinds(vec2 uv, float p) {
    float count = 14.0;
    float slat = floor(uv.y * count);
    float local = fract(uv.y * count);
    float t = clamp(p * 1.5 - slat / count * 0.5, 0.0, 1.0);
    float m = 1.0 - smoothstep(t - 0.03, t, abs(local - 0.5) * 2.0);
    return mix(A(uv), B(uv), t >= 1.0 ? 1.0 : m);
}

// The new picture pushes the old one out to the left.
vec4 push(vec2 uv, float p) {
    if (uv.x < 1.0 - p)
        return A(vec2(uv.x + p, uv.y));
    return B(vec2(uv.x - (1.0 - p), uv.y));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(progress, 0.0, 1.0);
    int e = int(effect + 0.5);
    vec4 c;
    if (e == 1) c = grow(uv, p);
    else if (e == 2) c = wipe(uv, p);
    else if (e == 3) c = wave(uv, p);
    else if (e == 4) c = dissolve(uv, p);
    else if (e == 5) c = pixels(uv, p);
    else if (e == 6) c = blocks(uv, p);
    else if (e == 7) c = shatter(uv, p);
    else if (e == 8) c = glitch(uv, p);
    else if (e == 9) c = melt(uv, p);
    else if (e == 10) c = ripple(uv, p);
    else if (e == 11) c = zoom(uv, p);
    else if (e == 12) c = swirl(uv, p);
    else if (e == 13) c = blinds(uv, p);
    else if (e == 14) c = push(uv, p);
    else c = fade(uv, p);
    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
