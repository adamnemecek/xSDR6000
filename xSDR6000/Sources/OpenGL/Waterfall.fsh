//
// Waterfall Fragment Shader
//  xSDR6000
//

#version 330 core

uniform sampler2D texValues;    // 2D waterfall

in vec2 passTexCoord;           // texture coordinates
out vec4 outColor;              // Color output

void main()
{
    // use the texture derived color
    outColor = texture(texValues, passTexCoord);
}
