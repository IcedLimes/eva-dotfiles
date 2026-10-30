#version 440
// The night sky behind Unit-01 (Stars.qml). The star map (~/.config/eva/stars.png,
// see ~/.config/eva/tools/make-stars.py) gives each texel a brightness (R),
// when its star comes out (G) and whether it's sky (A).
// Compile: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o stars.frag.qsb stars.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float clock;      // s since the record docked
    float span;       // s that G = 1 stands for
    float fade;       // the whole sky, 0..1
};

layout(binding = 1) uniform sampler2D field;

void main() {
    vec4 t = texture(field, qt_TexCoord0);
    float v = t.r * smoothstep(0.0, 0.7, clock - t.g * span) * t.a * fade;
    fragColor = vec4(v, v, v, v) * qt_Opacity;
}
