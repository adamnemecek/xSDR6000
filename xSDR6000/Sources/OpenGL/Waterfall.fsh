//
// Waterfall Fragment Shader
//  xSDR6000
//

#version 330 core

uniform sampler2D texValues;    // 2D waterfall
uniform sampler1D gradient;     // color gradient

in vec2 passTexCoord;           // texture coordinates

uint intensity;                 // intensity for a fragment
float scaled;                   // scaled intensity

out vec4 outColor;              // Color output

void main()
{
    
    // use the texture derived color
    outColor = texture(texValues, passTexCoord);

//    // get the intensity from the texture
//    intensity = texture(texValues, passTexCoord);
//    
//    // scale it
//    scaled = (float(intensity)/float(65536)) * float(256)
    
//    // convert the intensity to a gradient color
//    outcolor = texture(float(255), gradient);
}
