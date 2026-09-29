#version 330 core

layout (location = 0) in vec3 aVertex;
layout (location = 1) in vec2 aTexCoords;
layout (location = 2) in vec4 aColor;

layout (location = 3) in vec2 srcoff;
layout (location = 4) in vec2 srcscale;

layout (location = 5) in vec2 destoff;
layout (location = 6) in vec2 destscale;

uniform mat4 projection;

out vec2 texCoords;
out vec4 tintColor;

void main()
{
    vec2 p = aVertex.xy;
    p = p * (1.0 + destscale) + destoff;

    gl_Position = projection * vec4(round(p), aVertex.z, 1.0);
    texCoords = aTexCoords * (1.0 + srcscale) + srcoff;
    tintColor = aColor;
}
