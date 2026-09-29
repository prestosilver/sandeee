#version 330 core
layout (location = 0) in vec3 aVertex;

uniform float screen_width = 1024;
uniform float screen_height = 600;

out vec3 SCREEN_UV;

void main()
{
    gl_Position = vec4(round(aVertex.x * screen_width), round(aVertex.y * screen_height), 0.0 , 1.0);
    SCREEN_UV = gl_Position.xyz;
}
