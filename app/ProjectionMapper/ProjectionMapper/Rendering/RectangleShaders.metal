#include <metal_stdlib>
using namespace metal;

struct RectangleVertexOutput {
    float4 position [[position]];
};

// The caller supplies clip-space positions; scene-coordinate conversion belongs to Swift.
vertex RectangleVertexOutput rectangleVertex(uint vertexID [[vertex_id]],
                                            constant float2 *positions [[buffer(0)]]) {
    return { float4(positions[vertexID], 0.0, 1.0) };
}

fragment float4 rectangleFragment(constant float4 &color [[buffer(0)]]) {
    return color;
}
