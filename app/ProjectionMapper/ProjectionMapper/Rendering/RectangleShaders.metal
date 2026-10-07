#include <metal_stdlib>
using namespace metal;

struct RectangleVertexOutput {
    float4 position [[position]];
    float2 surfacePosition;
};

vertex RectangleVertexOutput rectangleVertex(uint vertexID [[vertex_id]],
                                            constant float2 *positions [[buffer(0)]]) {
    float2 clip = positions[vertexID];
    return { float4(clip, 0.0, 1.0), float2((clip.x + 1.0) * 0.5, (1.0 - clip.y) * 0.5) };
}

// Integer hashing avoids frame-order state and platform-dependent sin-based random seeds.
uint hashValue(uint value) {
    value ^= value >> 16; value *= 0x7feb352du; value ^= value >> 15;
    value *= 0x846ca68bu; return value ^ (value >> 16);
}
float randomValue(int2 cell, uint seed) {
    return float(hashValue(uint(cell.x) * 73856093u ^ uint(cell.y) * 19349663u ^ seed)) / 4294967295.0;
}
float valueNoise(float2 uv, uint seed) {
    int2 cell = int2(floor(uv)); float2 f = fract(uv); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(randomValue(cell,seed),randomValue(cell+int2(1,0),seed),f.x),
               mix(randomValue(cell+int2(0,1),seed),randomValue(cell+int2(1,1),seed),f.x),f.y);
}

float4 applyAppearance(float4 value, float2 appearance, float masterGain) {
    // Attenuate clipped RGB, preserving alpha so lower layers are never revealed.
    return float4(clamp(value.rgb * appearance.y,0.0,1.0) * masterGain,value.a * appearance.x);
}

// Matches CPU membership: include outer edges and exclude hole edges.
int maskLocation(float2 p, constant float2 *points, uint2 ring) {
    bool inside = false;
    for (uint i = 0; i < ring.y; ++i) {
        float2 a = points[ring.x+i], b = points[ring.x+(i+1)%ring.y];
        float2 edge = b-a, delta = p-a;
        if (abs(edge.x*delta.y-edge.y*delta.x) <= 1e-6 && dot(p-a,p-b) <= 1e-6) return 0;
        if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside = !inside;
    }
    return inside ? 1 : -1;
}

fragment float4 rectangleFragment(RectangleVertexOutput input [[stage_in]],
                                 constant float4 &color [[buffer(0)]],
                                 constant float3x3 &inverse [[buffer(1)]],
                                 constant uint &textured [[buffer(2)]],
                                 constant float3x3 &inputMap [[buffer(3)]],
                                 constant float &phase [[buffer(4)]],
                                 constant float4 &secondary [[buffer(5)]],
                                 constant float4 &parameters [[buffer(6)]],
                                 constant float2 &motion [[buffer(7)]],
                                 constant uint &seed [[buffer(8)]],
                                 constant float2 &appearance [[buffer(9)]],
                                 constant float &masterGain [[buffer(10)]],
                                 constant float4 &calibration [[buffer(11)]],
                                 constant uint2 *maskRings [[buffer(12)]],
                                 constant float2 *maskPoints [[buffer(13)]],
                                 texture2d<float> grid [[texture(0)]]) {
    // Clip in original face UV before EVERY content/calibration branch.
    if (maskRings[0].y > 0) {
        float3 mapped = inverse * float3(input.surfacePosition, 1.0);
        if (!all(isfinite(mapped)) || abs(mapped.z) < 1e-8) discard_fragment();
        float2 uv = mapped.xy / mapped.z;
        if (maskLocation(uv,maskPoints,maskRings[0]) < 0) discard_fragment();
        for (uint ring = 1; ring < 8; ++ring) {
            if (maskRings[ring].y > 0 && maskLocation(uv,maskPoints,maskRings[ring]) >= 0) discard_fragment();
        }
    }
    if (calibration.x > 0.5) {
        float3 mapped = inverse * float3(input.surfacePosition, 1.0);
        if (!all(isfinite(mapped)) || abs(mapped.z) < 1e-8) discard_fragment();
        float2 faceUV = mapped.xy / mapped.z;
        float2 ownerUV = (inputMap * float3(faceUV, 1.0)).xy;
        uint pattern = uint(calibration.x);
        float value = 0.0;
        if (pattern == 1) {
            float2 cells = ownerUV * calibration.yz;
            float2 width = max(fwidth(cells), float2(1e-6));
            float2 distance = abs(fract(cells + 0.5) - 0.5) / width;
            value = 1.0 - smoothstep(max(0.0, calibration.w * 0.5 - 0.5), calibration.w * 0.5 + 0.5, min(distance.x, distance.y));
        } else if (pattern == 2) {
            float2 cells = ownerUV * calibration.yz;
            float2 wave = sin(3.14159265 * cells);
            // Integrate the alternating cell sign across a derivative-sized edge footprint.
            float2 edge = max(fwidth(cells) * 3.14159265, float2(1e-6));
            float2 sign = smoothstep(-edge * 0.5, edge * 0.5, wave);
            value = sign.x * sign.y + (1.0 - sign.x) * (1.0 - sign.y);
        } else if (pattern == 3) {
            float2 width = max(fwidth(faceUV), float2(1e-6));
            float2 center = abs(faceUV - 0.5) / width;
            float2 border = min(abs(faceUV), abs(1.0 - faceUV)) / width;
            float distance = min(min(center.x, center.y), min(border.x, border.y));
            value = 1.0 - smoothstep(max(0.0, calibration.w * 0.5 - 0.5), calibration.w * 0.5 + 0.5, distance);
        } else if (pattern == 4) { value = 1.0; }
        else if (pattern == 6 || pattern == 7) {
            float cells = pattern == 6 ? ownerUV.x * calibration.y : ownerUV.y * calibration.z;
            float wave = sin(3.14159265 * cells);
            float edge = max(fwidth(cells) * 3.14159265, 1e-6);
            value = smoothstep(-edge * 0.5, edge * 0.5, wave);
        }
        return float4(float3(value * masterGain), 1.0);
    }
    if (textured == 0) return applyAppearance(color,appearance,masterGain);
    // Applying one homography after interpolation avoids a diagonal UV seam.
    float3 homogeneous = inverse * float3(input.surfacePosition, 1.0);
    if (!all(isfinite(homogeneous)) || abs(homogeneous.z) < 1e-8) return float4(0, 0, 0, 1);
    float2 uv = (inputMap * float3(homogeneous.xy / homogeneous.z, 1.0)).xy;
    float scale = parameters.x;
    float2 oriented = float2(dot(uv,motion), dot(uv,float2(-motion.y,motion.x)));
    if (textured == 2) {
        float blend = 0.5 + 0.5 * sin(6.2831853 * (oriented.x * scale - phase));
        return applyAppearance(mix(color, secondary, blend),appearance,masterGain);
    }
    if (textured == 3) {
        float wave = 0.5 + 0.5 * sin(6.2831853 * 8.0 * (oriented.x * scale - phase));
        float width = max(fwidth(wave), 0.002);
        return applyAppearance(mix(secondary, color, smoothstep(0.5 - width, 0.5 + width, wave)),appearance,masterGain);
    }
    if (textured == 4) {
        // Analytic antialiased checker waves, sampled in the owner's shared canvas.
        float2 wave = sin(6.2831853 * 4.0 * (oriented * scale - float2(phase, phase)));
        float checker = wave.x * wave.y;
        float width = max(fwidth(checker), 0.002);
        return applyAppearance(mix(secondary, color, smoothstep(-width, width, checker)),appearance,masterGain);
    }
    if (textured == 5) {
        float2 p = oriented * scale * 6.2831853;
        float t = phase * 6.2831853;
        float blend = 0.5 + parameters.y * (sin(p.x + t) + sin(p.y - t) + sin(p.x+p.y+2.0*cos(t))) / 6.0;
        return applyAppearance(mix(color,secondary,clamp(blend,0.0,1.0)),appearance,masterGain);
    }
    if (textured == 6) {
        float t = phase * 6.2831853;
        float blend = valueNoise(uv * scale * 12.0 + float2(cos(t),sin(t)) * 2.0,seed);
        return applyAppearance(mix(color,secondary,clamp(0.5 + (blend-0.5)*parameters.y*2.0,0.0,1.0)),appearance,masterGain);
    }
    if (textured == 7) {
        int count = int(parameters.z);
        float2 p = fract(uv - motion * phase) * float(count);
        int2 base = int2(floor(p)); float glow = 0.0;
        // One seeded particle per cell; only nine local cells can intersect this pixel.
        for (int y=-1; y<=1; ++y) for (int x=-1; x<=1; ++x) {
            int2 cell = base + int2(x,y);
            int2 wrapped = (cell + count) % count;
            float2 center = float2(randomValue(wrapped,seed), randomValue(wrapped,seed ^ 0x9e3779b9u));
            float distance = length(p - (float2(cell)+center));
            float edge = max(length(fwidth(p)),0.002);
            glow = max(glow,1.0-smoothstep(max(0.0,parameters.w-edge),parameters.w+edge,distance));
        }
        return applyAppearance(mix(secondary,color,glow),appearance,masterGain);
    }
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    return applyAppearance(grid.sample(sampling, uv),appearance,masterGain);
}
