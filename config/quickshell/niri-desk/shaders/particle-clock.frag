#version 440
// Dots on a grid form the digits. Each pixel asks which dots lie near it, so nothing is simulated
// and the cost does not depend on the number of dots.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 pointer;
    float push;
    float time;
    float tremble;
    float blend;
    float assemble;
    float topY;
    float bottomY;
    vec4 colorTop;
    vec4 colorBottom;
};
layout(binding = 1) uniform sampler2D digitsA;
layout(binding = 2) uniform sampler2D digitsB;

const float GRID = 5.0;
const float DOT = 1.7;
const float REACH = 110.0;
const float THROW = 46.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Pushes a point away from the pointer. The distance grows steadily, so the inverse exists.
vec2 flee(vec2 p) {
    vec2 away = p - pointer;
    float far = length(away) + 0.001;
    float k = max(0.0, 1.0 - far / REACH);
    return away / far * THROW * k * k * push;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 base = floor((p - flee(p)) / GRID + 0.5) * GRID;
    float light = 0.0;
    float change = sin(blend * 3.14159);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 home = base + vec2(x, y) * GRID;
            vec2 uv = home / size;
            float luck = hash(home);
            // Each dot moves over to the new digits at its own moment.
            float cover = luck < blend ? texture(digitsB, uv).a : texture(digitsA, uv).a;
            if (cover < 0.5)
                continue;
            float angle = luck * 6.28318;
            vec2 shake = vec2(sin(time * 2.0 + angle), cos(time * 2.33 + angle * 1.3)) * tremble;
            vec2 scatter = vec2(cos(angle * 7.0), sin(angle * 7.0)) * (change * 4.0 + (1.0 - assemble) * 4.0);
            vec2 center = home + flee(home) + shake + scatter;
            float appear = smoothstep(luck * 0.8, luck * 0.8 + 0.2, assemble);
            light = max(light, (1.0 - smoothstep(DOT - 0.6, DOT + 0.6, length(p - center))) * appear);
        }
    }
    vec4 shade = mix(colorTop, colorBottom, clamp((p.y - topY) / (bottomY - topY), 0.0, 1.0));
    fragColor = vec4(shade.rgb, 1.0) * light * qt_Opacity;
}
