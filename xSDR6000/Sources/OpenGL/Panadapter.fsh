//
// Panadapter Fragment Shader
//  xSDR6000
//

#version 330 core

uniform vec4 lineColor;

out vec4 outColor;

void main()
{
    // set the vertex color
    outColor = lineColor;
}
