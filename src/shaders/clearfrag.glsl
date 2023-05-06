#version 330 core

in vec2 texCoords;
in vec4 tintColor;

out vec4 color;

uniform sampler2D tex;

void main() {
  color = vec4(0, 0, 0, ( int(texCoords.x) % 4 ) < 2 ^^ (int(texCoords.y) % 4) < 2 ? 1.0 : 0);
}
