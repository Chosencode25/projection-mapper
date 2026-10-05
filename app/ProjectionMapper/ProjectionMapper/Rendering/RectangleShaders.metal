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

fragment float4 rectangleFragment(RectangleVertexOutput input [[stage_in]],
                                 constant float4 &color [[buffer(0)]],
                                 constant float3x3 &inverse [[buffer(1)]],
                                 constant uint &textured [[buffer(2)]],
                                 texture2d<float> grid [[texture(0)]]) {
    if (textured == 0) return color;
    // Applying one homography after interpolation avoids a diagonal UV seam.
    float3 homogeneous = inverse * float3(input.surfacePosition, 1.0);
    if (!all(isfinite(homogeneous)) || abs(homogeneous.z) < 1e-8) return float4(0, 0, 0, 1);
    float2 uv = homogeneous.xy / homogeneous.z;
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    return grid.sample(sampling, uv);
}
