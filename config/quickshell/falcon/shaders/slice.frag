#version 440
// One slice of the wallpaper picker (modules/WallpaperPicker.qml): a slanted card with round
// corners, its picture upright inside it, a frame, a dim veil and a soft shadow, all in one pass.
// While the row moves, `bend` curls the card like a page pulled through the air and splits the
// colors a little at its edges. Coordinates are pixels from the middle of the item.
// Rebuild after a change: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o slice.frag.qsb slice.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 box;          // the item's size
    vec2 extent;         // half of the middle line width, half of the height
    float skew;        // how far the top edge lies right of the bottom one
    float radius;
    float bend;        // -1..1, from the speed of the row
    float dim;         // 0..1 black veil
    float frame;       // frame width in px
    vec4 frameColor;   // opaque, its strength is frameAlpha
    float frameAlpha;
    float texAspect;   // width over height of each picture
    float hiAspect;
    float hiMix;       // 0 shows `source`, 1 shows `hiSource`
    float shift;       // -1..1, slides the picture inside the card
    float shadow;      // 0..1
    float glow;        // 0..1, light along the frame of the chosen card
    float centerY;     // how far below the item's middle the card's middle lies
    float reflection;  // 0..1, strength of the mirror image on the floor under the card
    float reflectSize; // how far down the mirror image reaches, in px
    float zoom;        // >= 1, slow zoom of the picture
    vec2 pan;          // -1..1, where the zoomed picture looks
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D hiSource;

float roundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Distance to the slanted card: shearing x back makes it a plain rounded box.
float card(vec2 p) {
    float x = p.x + skew * 0.5 * (p.y / max(extent.y, 1.0));
    float r = min(radius, min(extent.x, extent.y));
    return roundBox(vec2(x, p.y), extent, r);
}

vec2 cover(vec2 norm, float aspect, float slide) {
    float span = extent.x + abs(skew) * 0.5;
    float cardAspect = span / max(extent.y, 1.0);
    vec2 uv = 0.5 + (norm - 0.5) / max(zoom, 1.0) + pan * (1.0 - 1.0 / max(zoom, 1.0)) * 0.5;
    if (aspect > cardAspect) {
        float k = cardAspect / aspect;
        uv.x = 0.5 + (uv.x - 0.5) * k + slide * (1.0 - k) * 0.5;
    } else {
        uv.y = 0.5 + (uv.y - 0.5) * aspect / cardAspect;
    }
    return clamp(uv, vec2(0.001), vec2(0.999));
}

vec3 picture(vec2 norm, float ca) {
    vec2 a = cover(norm, texAspect, shift);
    vec3 lo = vec3(texture(source, a + vec2(ca, 0.0)).r, texture(source, a).g, texture(source, a - vec2(ca, 0.0)).b);
    if (hiMix <= 0.001)
        return lo;
    vec2 b = cover(norm, hiAspect, shift);
    vec3 hi = vec3(texture(hiSource, b + vec2(ca, 0.0)).r, texture(hiSource, b).g, texture(hiSource, b - vec2(ca, 0.0)).b);
    return mix(lo, hi, hiMix);
}

// The card at p: its color, already veiled and framed, and its coverage.
vec4 cardAt(vec2 p, float b, bool mirror) {
    vec2 loc = p;
    float yn = clamp(loc.y / max(extent.y, 1.0), -1.35, 1.35);
    loc.x -= b * extent.x * 0.5 * yn * yn;
    loc.y *= 1.0 + abs(b) * 0.1 * (1.0 - clamp(abs(loc.x / max(extent.x, 1.0)), 0.0, 1.0));
    float d = card(loc);
    float aa = max(fwidth(d), 0.0001);
    float a = clamp(0.5 - d / aa, 0.0, 1.0);
    if (a <= 0.0)
        return vec4(0.0);
    float span = extent.x + abs(skew) * 0.5;
    vec2 norm = vec2(loc.x / (2.0 * span) + 0.5, loc.y / (2.0 * extent.y) + 0.5);
    vec3 col = picture(norm, abs(b) * 0.014);
    col = mix(col, vec3(0.0), dim);
    if (!mirror) {
        float top = clamp(1.0 - (norm.y / 0.35), 0.0, 1.0);
        col += vec3(0.07) * glow * top * top;
        float stroke = abs(d + frame * 0.5) - frame * 0.5;
        float fa = clamp(0.5 - stroke / aa, 0.0, 1.0) * frameAlpha * step(0.001, frame);
        col = col * (1.0 - fa) + frameColor.rgb * fa;
    }
    return vec4(col, a);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * box - vec2(0.0, centerY);

    // The soft shadow, under the card and a little below it.
    float ds = card(p - vec2(3.0, 9.0) * (0.6 + 0.4 * shadow));
    float blur = 22.0;
    float sh = shadow * 0.55 * pow(clamp(1.0 - (ds + blur * 0.2) / blur, 0.0, 1.0), 1.7);

    float b = clamp(bend, -1.2, 1.2);
    vec4 under = vec4(0.0, 0.0, 0.0, sh);

    // The mirror image on a dark glossy floor: the card flipped about a line just under it,
    // fading out downward.
    float floorY = extent.y + 6.0;
    if (reflection > 0.0 && p.y > floorY) {
        float depth = (p.y - floorY) / max(reflectSize, 1.0);
        if (depth < 1.0) {
            vec4 m = cardAt(vec2(p.x, 2.0 * floorY - p.y), b, true);
            float fade = reflection * pow(1.0 - depth, 2.0) * 0.5;
            vec4 mirrorColor = vec4(m.rgb * m.a * fade, m.a * fade);
            under = mirrorColor + under * (1.0 - mirrorColor.a);
        }
    }

    vec4 c = cardAt(p, b, false);
    fragColor = (vec4(c.rgb * c.a, c.a) + under * (1.0 - c.a)) * qt_Opacity;
}
