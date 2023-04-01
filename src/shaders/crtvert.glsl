#version 330 core
layout (location = 0) in vec3 aVertex;

out vec3 SCREEN_UV;

void main()
{
    gl_Position = vec4(aVertex.x * 2560, aVertex.y * 1080, 0.0 , 1.0);
    SCREEN_UV = gl_Position.xyz;
}
