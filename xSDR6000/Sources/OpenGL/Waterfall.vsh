//
// Waterfall Vertex Shader
//  xSDR6000
//

#version 330 core

layout (location = 0) in vec2 position;             // vertex
layout (location = 1) in vec2 texCoord;             // texture coordinate

out vec2 passTexCoord;

void main()
{
    
    // set the position
    gl_Position = vec4(position, 0.0, 1.0);
    
    // pass the Texture coordinates to the fragment shader
    passTexCoord = texCoord;
    
}
