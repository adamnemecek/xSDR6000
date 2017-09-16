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
    ushort  y;
};

struct Uniforms {
    float   delta;
    float   height;
    float4  spectrumColor;
    float4  gridColor;
    bool    textureEnable;
};

struct VertexOutput {
    float4  coord [[ position ]];
    float2  texCoord;
    float4  spectrumColor;
    float4  gridColor;
    bool    textureEnable;
};

// Vertex Shader
//
//  Parameters:
//      vertices:       an array of vertices at index 0 (in problem space as a uint2, i.e. 32-bit unsigned)
//      vertexId:       a system generated vertex index
//      uniforms:       the unifirm struct
//
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
    
    unsigned int effectiveVertexId;
    
    // calculate a effectiveVertexID value that matches the data layout
    effectiveVertexId = (vertexId - (vertexId % 2)) / 2;
    
    // use the effective Vertex Id to calculate the x coordinate
    xCoord = (uniforms.delta * effectiveVertexId) - 1;
    
    // is this a "real" or a "synthetic" value?
    if (vertexId % 2 == 0) {
        
        // "synthetic", y values are always -1
        yCoord = - 1;
    
    } else {
        
        // "real", y values must be flipped and normalized
        yCoord = -(( 2.0 * vertices[vertexId].y)/uniforms.height) + 1;
    }
    
    // send values to the fragment stage
    v_out.coord = float4( xCoord, yCoord, 0.0, 1.0);
    v_out.spectrumColor = uniforms.spectrumColor;
    v_out.gridColor = uniforms.gridColor;
    v_out.textureEnable = uniforms.textureEnable;
    
    // calculate the texture coordinates
    if (vertexId % 2 == 0) {
        v_out.texCoord = float2(0.0, 1.0);
    } else {
        v_out.texCoord = float2(0.0, 0.0);
    }
    
    return v_out;
}

// Fragment Shader
//
//  Parameters:
//      in:         VertexOutput struct
//      tex2d:      a 2d texture
//      sampler2d:  the sampler for the texture
//
//  Returns:
//      a float4 vector of the fragment's color (always black in this example)
//
fragment float4 pan_fragment( VertexOutput in [[ stage_in ]],
                             texture2d<float, access::sample> tex2d [[texture(0)]],
                             sampler sampler2d [[sampler(0)]])
{
    // are we drawing the texture?
    if (in.textureEnable == false) {
        
        // NO, use the uniform color
        return in.spectrumColor;
    
    } else {
        
        // YES, combine the texture with the uniform color
        return float4( tex2d.sample(sampler2d, in.texCoord).rgba) * float4(in.spectrumColor.rgb, 1.0);
    }
    
}
