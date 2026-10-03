/*
 * Original work Copyright 2024 LiveKit, Inc.
 * Modifications Copyright 2025 Eleven Labs Inc.
 * Licensed under the Apache License, Version 2.0.
 * http://www.apache.org/licenses/LICENSE-2.0
 * Distributed on an AS IS BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.
 * DreamJourney adaptation: UIKit lifecycle, real PCM envelopes and blue-white rendering.
 */
// Adapted for DreamJourney 2026-10-03: blue-white palette, soft circular mask.
// Upstream ElevenLabs components-swift; Apache-2.0. See bundled EchoOrb-NOTICE.txt.
//
//  OrbShader.metal
//  ElevenLabs swift components
//
//  Created by Louis Jordan on 06/17/2025.
//

#include <metal_stdlib>
using namespace metal;

constant float PI = 3.14159265358979323846;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct OrbUniforms {
    float time;
    float animation;
    float inverted;
    float _pad0; // padding to 16 bytes alignment
    float offsets[8]; // 8 offsets for alignment
    float4 color1;
    float4 color2;
    float inputVolume;
    float outputVolume;
    float2 _pad1; // 8 bytes padding to reach 96 bytes
};

vertex VertexOut echoOrbVertexShader(uint vertexID [[vertex_id]],
                                 constant float2* vertices [[buffer(0)]]) {
    VertexOut out;
    float2 pos = vertices[vertexID];
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5; // Convert from [-1,1] to [0,1]
    return out;
}

float2 hash2(float2 p) {
    return fract(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453);
}

float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float2 u = f * f * (3.0 - 2.0 * f);
    float n = mix(
        mix(dot(hash2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
            dot(hash2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
        mix(dot(hash2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
            dot(hash2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x),
        u.y
    );

    return 0.5 + 0.5 * n;
}

// DreamJourney cloud adaptation: Cartesian domain warping avoids the pinwheel
// singularity at the centre of the upstream polar renderer.
float cloudField(float2 p) {
    float n = noise2D(p) * 0.58;
    p = float2(p.x * 1.73 - p.y * 0.93, p.x * 0.93 + p.y * 1.73);
    n += noise2D(p + 3.1) * 0.28;
    n += noise2D(p * 2.03 + 8.7) * 0.14;
    return n;
}
fragment float4 echoOrbFragmentShader(VertexOut in [[stage_in]],
                                  constant OrbUniforms& uniforms [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float radius = length(uv);
    float alpha = 1.0 - smoothstep(0.96, 1.0, radius);
    if (alpha <= 0.0) return float4(0.0);
    float depth = sqrt(max(0.0, 1.0 - radius * radius));
    float input = uniforms.inputVolume;
    float output = uniforms.outputVolume;
    float t = uniforms.animation;
    float2 p = uv * (1.35 + 0.3 * depth + input * 0.24);
    float angle = 0.12 * t + output * 0.35 * depth;
    p = float2(cos(angle) * p.x - sin(angle) * p.y,
               sin(angle) * p.x + cos(angle) * p.y);
    p += float2(t * 0.13, -t * 0.08);
    float2 warp = float2(cloudField(p + float2(t * 0.12, 2.4)),
                        cloudField(p + float2(5.1, -t * 0.1))) - 0.5;
    float density = cloudField(p + warp * (3.0 + output * 1.8));
    float clouds = smoothstep(0.43 - input * 0.015, 0.59, density);
    float light = clamp(0.55 + depth * 0.38 + uv.y * 0.1 - uv.x * 0.08, 0.0, 1.0);
    float3 sky = mix(uniforms.color1.rgb * 0.85, uniforms.color2.rgb, light * 0.45);
    float3 white = mix(uniforms.color2.rgb, float3(1.0), 0.85);
    float3 color = mix(sky, white, clouds);
    float rim = pow(1.0 - depth, 3.0) * 0.4;
    color = mix(color, uniforms.color2.rgb, rim);
    return float4(color * alpha, alpha);
}
