#version 440
// Liquid glass (Liquid.qml): a rounded box melted into what it grows out of
// (the screen's frame for the dock, the dock for the start menu) with a
// smooth union, so the joins flare out like a drop of water instead of
// meeting at a corner. The screen's frame is a band around the screen with
// rounded inner corners. Windows that melt into each other each draw the
// union on their own side of a split (clipTop, insideOnly / exclude), so
// there's no seam. Tinted glass (Hyprland blurs behind it), a light outline,
// a soft shadow, and a ripple: a ring of light spreading from a point that
// also pushes the glass edge out as it passes.
// Compile: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o liquid.frag.qsb liquid.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 px;           // the item in px
    vec4 box;          // the glass: x, y, w, h (px)
    float radius;      // its corner radius
    vec4 anchor;       // a shape it grows out of: x, y, w, h (px); w = 0: none
    float anchorRadius;
    float fillet;      // how far the joins flare (px)
    vec4 anchor2;      // a second one (the start menu, seen from the dock)
    float anchor2Radius;
    float fillet2;
    vec4 frameRect;    // the screen frame's inside edge: x, y, w, h (px); w = 0: no frame
    float frameRadius;
    float frameFillet;
    float clipTop;     // no glass above this y (px): the other window draws it there
    float insideOnly;  // 1: glass only inside the frame (the dock's side of the join)
    vec4 exclude;      // no glass in here inside the frame (the frame skipping the dock's side)
    vec4 tint;         // glass color
    vec4 edge;         // outline color
    float rimWidth;    // outline width (px)
    float shadow;      // shadow strength, 0..1
    vec4 ripple;       // x, y (px), progress 0..1, strength
    vec2 rippleShape;  // how far it spreads (px), how far it pushes the edge out (px)
};

float roundBox(vec2 p, vec4 b, float r) {
    vec2 h = b.zw * 0.5;
    r = min(r, min(h.x, h.y));
    vec2 q = abs(p - (b.xy + h)) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// the ripple's ring at p: 0..1
float ring(vec2 p) {
    if (ripple.w <= 0.0 || ripple.z <= 0.0 || ripple.z >= 1.0)
        return 0.0;
    float t = ripple.z;
    float r = mix(8.0, rippleShape.x, 1.0 - (1.0 - t) * (1.0 - t));   // spreads fast, then slows
    float w = mix(4.0, 6.0 + rippleShape.x * 0.05, t);                 // and broadens as it goes
    return exp(-pow((length(p - ripple.xy) - r) / w, 2.0)) * ripple.w * pow(1.0 - t, 1.4);
}

float shape(vec2 p, float wave) {
    float d = box.z > 0.5 && box.w > 0.5 ? roundBox(p, box, radius) : 1e4;
    if (anchor.z > 0.0)
        d = smin(d, roundBox(p, anchor, anchorRadius), max(fillet, 0.001));
    if (anchor2.z > 0.0)
        d = smin(d, roundBox(p, anchor2, anchor2Radius), max(fillet2, 0.001));
    if (frameRect.z > 0.0)
        d = smin(d, -roundBox(p, frameRect, frameRadius), max(frameFillet, 0.001));
    return d - wave * rippleShape.y;   // the passing wave pushes the edge out
}

void main() {
    vec2 p = qt_TexCoord0 * px;
    float wave = ring(p);
    float d = shape(p, wave);

    float solid = clamp(0.5 - d, 0.0, 1.0);
    float side = clamp(p.y - clipTop + 0.5, 0.0, 1.0);
    if (frameRect.z > 0.0) {
        float inFrame = clamp(0.5 - roundBox(p, frameRect, frameRadius), 0.0, 1.0);
        if (insideOnly > 0.5)
            side *= inFrame;
        else if (exclude.z > 0.0) {
            vec2 e = step(exclude.xy, p) * step(p, exclude.xy + exclude.zw);
            side *= 1.0 - inFrame * e.x * e.y;
        }
    }
    float inside = solid * side;

    // the outline, just inside the edge
    float rim = clamp(rimWidth * 0.5 + 0.5 - abs(d + rimWidth * 0.5 + 0.5), 0.0, 1.0) * inside;
    vec4 col = vec4(tint.rgb * tint.a, tint.a) * inside;
    col = col * (1.0 - rim * edge.a) + vec4(edge.rgb, 1.0) * rim * edge.a;

    // soft shadow below, outside the glass only (kept under the blur threshold)
    if (shadow > 0.0) {
        float ds = shape(p - vec2(0.0, 6.0), 0.0);
        float sh = shadow * 0.32 * exp(-max(ds, 0.0) / 14.0) * (1.0 - solid) * side;
        col += vec4(0.0, 0.0, 0.0, sh) * (1.0 - col.a);
    }

    // the ripple's light, inside the glass only
    float a = wave * 0.5 * inside;
    col = col * (1.0 - a) + vec4(a, a, a, a);

    fragColor = col * qt_Opacity;
}
