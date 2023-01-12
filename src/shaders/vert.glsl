#version 330 core
layout (location = 0) in vec3 aVertex;
layout (location = 1) in vec2 aTexCoords;
layout (location = 2) in vec4 aColor;
uniform mat4 projection;
out vec2 texCoords;
out vec4 tintColor;
void main()
{
    gl_Position = projection * vec4(aVertex.xyz, 1.0);
    texCoords = aTexCoords;
    tintColor = aColor;
}
