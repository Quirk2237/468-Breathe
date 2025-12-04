#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader Structures
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Uniforms
struct Uniforms {
    float time;
    float expansion;
    float2 resolution;
    float4 color;
    float speed;
    float _padding1;
    float _padding2;
    float _padding3;
};

// MARK: - Simplex 2D Noise (ported from GLSL)
float3 permute(float3 x) {
    return fmod(((x * 34.0) + 1.0) * x, 289.0);
}

float snoise(float2 v) {
    const float4 C = float4(0.211324865405187, 0.366025403784439,
                            -0.577350269189626, 0.024390243902439);
    
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    
    i = fmod(i, 289.0);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0))
                       + i.x + float3(0.0, i1.x, 1.0));
    
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    
    return 130.0 * dot(m, g);
}

// MARK: - Vertex Shader
vertex VertexOut bubbleVertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Fragment Shader
fragment float4 bubbleFragment(VertexOut in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = (in.texCoord - 0.5) * 2.0;
    float len = length(uv);
    float angle = atan2(uv.y, uv.x);
    
    float baseRadius = 0.35 + (uniforms.expansion * 0.45);
    
    float noiseScale = 1.4;
    float timeScale = uniforms.time * 0.4 * uniforms.speed;
    float n = snoise(float2(cos(angle) * noiseScale + timeScale,
                            sin(angle) * noiseScale + timeScale));
    
    float displacement = n * (0.03 + 0.02 * uniforms.expansion);
    float r = baseRadius + displacement;
    float dist = len - r;
    
    float alphaShape = smoothstep(0.005, -0.005, dist);
    float innerGlow = smoothstep(-0.3, 0.0, dist) * 0.6;
    
    float2 highlightCenter = float2(-0.15, 0.15);
    float highlightDist = length(uv - highlightCenter);
    float highlightBase = smoothstep(0.25, 0.0, highlightDist);
    float highlightSpot = smoothstep(0.1, 0.0, highlightDist - 0.02);
    float highlight = (highlightBase * 0.3) + (highlightSpot * 0.3);
    highlight *= alphaShape;
    
    float3 bubbleColor = uniforms.color.xyz;
    float3 finalColor = bubbleColor * (0.4 + 0.6 * innerGlow);
    finalColor += float3(1.0, 1.0, 1.0) * highlight;
    
    return float4(finalColor, alphaShape);
}

// MARK: - Mini Bubble Shader
fragment float4 miniBubbleFragment(VertexOut in [[stage_in]],
                                    constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = (in.texCoord - 0.5) * 2.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float baseRadius = 0.35 + (uniforms.expansion * 0.05);
    
    float noiseScale = 2.0;
    float timeScale = uniforms.time * 0.3 * uniforms.speed;
    float angle = atan2(uv.y, uv.x);
    float len = length(uv);
    
    float n = snoise(float2(cos(angle) * noiseScale + timeScale,
                            sin(angle) * noiseScale + timeScale));
    
    float displacement = n * 0.02;
    float r = baseRadius + displacement;
    float dist = len - r;
    
    float alphaShape = smoothstep(0.01, -0.01, dist);
    float innerGlow = smoothstep(-0.4, 0.0, dist) * 0.5;
    
    float2 highlightCenter = float2(-0.12, 0.12);
    float highlightDist = length(uv - highlightCenter);
    float highlight = smoothstep(0.2, 0.0, highlightDist) * 0.4 * alphaShape;
    
    float3 bubbleColor = uniforms.color.xyz;
    float3 finalColor = bubbleColor * (0.5 + 0.5 * innerGlow);
    finalColor += float3(1.0) * highlight;
    
    return float4(finalColor, alphaShape);
}

// MARK: - Timer Ring Overlay
fragment float4 timerRingFragment(VertexOut in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = (in.texCoord - 0.5) * 2.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float len = length(uv);
    float angle = atan2(uv.y, -uv.x);
    float normalizedAngle = (angle + M_PI_F) / (2.0 * M_PI_F);
    
    float ringRadius = 0.47;
    float ringThickness = 0.05;
    
    float ringDist = abs(len - ringRadius);
    float ringAlpha = smoothstep(ringThickness, ringThickness * 0.5, ringDist);
    
    float progress = uniforms.expansion;
    float progressAlpha = normalizedAngle <= progress ? 1.0 : 0.3;
    
    float3 ringColor = uniforms.color.xyz;
    float finalAlpha = ringAlpha * progressAlpha * 0.8;
    
    return float4(ringColor, finalAlpha);
}

