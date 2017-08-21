//
// Panadapter Vertex Shader
//  xSDR6000
//

#version 330 core

layout (location = 0) in float yCoordinate;
layout (location = 1) in float xCoordinate;

uniform float delta;
uniform float height;

float xCalculated;
float yCalculated;

void main()
{
    // calculate the x position
    xCalculated = -1 + (gl_VertexID * delta);

    // normalize the y position
    yCalculated = 1 - ((2 * yCoordinate)/height);

    // set the vertex position
    gl_Position = vec4(xCalculated, yCalculated, 0.0, 1.0);
}
