//
//  Shaders.metal
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    uint2 coord;
    float2 texCoord;
};

struct Uniforms {
    float maxValue;
    float numberOfPoints;
    float3 color;
};

struct VertexOutput {
    float4 coord [[ position ]];
    float2 texCoord;
    float3 color;
};

// Vertex Shader with two input parameters
//  Parameters:
//      vertices:       an array of vertices at index 0 (in problem space as a uint2, i.e. 32-bit unsigned)
//      vid:            a system generated vertex index
//  Returns:
//      a VertexOutput struct
//
vertex VertexOutput pan_vertex(const device VertexInput* vertices [[ buffer(0) ]],
                               unsigned int vertexId [[ vertex_id ]],
                               constant Uniforms &uniforms [[ buffer(1) ]])
{
    
    VertexOutput v_out;
    float xCoord;
    float yCoord;
    
    // normalize the coordinates to clip space
    xCoord = ((float(vertices[vertexId].coord.x) / (uniforms.numberOfPoints - 1)) * 2.0) - 1.0;
    yCoord = ((float(vertices[vertexId].coord.y) / uniforms.maxValue) * 2.0) - 1.0;
    
    // send the clip space coords to the fragment stage
    v_out.coord = float4( xCoord, yCoord, 0.0, 1.0);
    v_out.texCoord = vertices[vertexId].texCoord;
    v_out.color = uniforms.color;
    
    return v_out;
}

// Fragment Shader with no input parameters
//  Parameters:
//      in:         VertexOutput struct
//
//  Returns:
//      a float4 vector of the fragment's color (always black in this example)
//
fragment float4 pan_fragment( VertexOutput in [[ stage_in ]],
                             texture2d<float, access::sample> tex2d [[texture(0)]],
                             sampler sampler2d [[sampler(0)]])
{
    // Sample the texture to get the color at this point (black & white)
    //    float4 color = float4(tex2d.sample(sampler2d, in.texCoord).rgba);
    
    return float4( tex2d.sample(sampler2d, in.texCoord).rgba) * float4(in.color.rgb, 0.5);
    //    return float4(0.5, 0.5, 0.0, 0.3);
}

