//
//  Shaders.metal
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// --------------------------------------------------------------------------------
// MARK: - Shader structures
// --------------------------------------------------------------------------------

struct SpectrumValue {                  // values for spectrum draw calls
    ushort  i;
};

struct Uniforms {                       // common uniforms
    float   delta;
    float   height;
    float4  spectrumColor;
    bool    textureEnable;
};

struct VertexOutput {                   // common vertex output
    float4  coord [[ position ]];
    float2  texCoord;
    float4  spectrumColor;
    bool    textureEnable;
};

// --------------------------------------------------------------------------------
// MARK: - Shaders for Panadapter Spectrum draw calls
// --------------------------------------------------------------------------------

// Spectrum vertex shader
//
//  Parameters:
//      vertices:       an array of vertices at position 0 (in problem space, ushort i.e. 16-bit unsigned)
//      vertexId:       a system generated vertex index
//      uniforms:       the unifirm struct at position 1
//
//  Returns:
//      a VertexOutput struct
//
vertex VertexOutput spectrum_vertex(const device SpectrumValue* intensities [[ buffer(0) ]],
                               unsigned int vertexId [[ vertex_id ]],
                               constant Uniforms &uniforms [[ buffer(1) ]])
{
    
    VertexOutput v_out;
    float xCoord;
    float yCoord;
    
    unsigned int effectiveVertexId;
    float intensity;
    
    // is this a "real" vertex?
    if (vertexId < 3000) {

        intensity = float(intensities[vertexId].i);
        // YES, y values must be flipped and normalized
        yCoord = -( (2.0 * intensity/uniforms.height ) - 1 );

        // use the vertexId "as-is"
        effectiveVertexId = vertexId;
        
        // set the texture coordinate to the bright side of the texture
        v_out.texCoord = float2(0.0, 0.0);
        
    } else {
        
        // YES, y value is always the bottom line
        yCoord = - 1;

        // calculate an effective vertexId
        effectiveVertexId = vertexId - 3000;
        
        // set the texture coordinate to the dark side of the texture
        v_out.texCoord = float2(0.0, 1.0);
    }
    // calculate the x coordinate  & normalize to clip space
    xCoord = ((float(effectiveVertexId) * uniforms.delta) * 2) - 1 ;

    // send the clip space coords to the fragment shader
    v_out.coord = float4( xCoord, yCoord, 0.0, 1.0);
    
    // pass the other uniforms to the fragment shader
    v_out.spectrumColor = uniforms.spectrumColor;
    v_out.textureEnable = uniforms.textureEnable;
    
    return v_out;
}

// Spectrum fragment shader
//  Parameters:
//      in:         VertexOutput struct
//
//  Returns:
//      the fragment color
//
fragment float4 spectrum_fragment( VertexOutput in [[ stage_in ]],
                             texture2d<float, access::sample> tex2d [[texture(0)]],
                             sampler sampler2d [[sampler(0)]])
{
    // is texturing enabled?
    if (in.textureEnable == false) {
        
        // NO, use a simple color
        return in.spectrumColor;
        
    } else {
        
        // YES, blend in the texture
        return float4( tex2d.sample(sampler2d, in.texCoord).rgba) * float4(in.spectrumColor.rgb, 1.0);
    }
    
}

