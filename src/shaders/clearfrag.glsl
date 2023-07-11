#version 330 core

in vec2 texCoords;
in vec4 tintColor;

out vec4 color;

uniform sampler2D tex;

void main() {
  //color = vec4(0, 0, 0, ( int(texCoords.x) % 8 ) < 4 ^^ (int(texCoords.y) % 8) < 4 ? 1.0 : 0);
  color = vec4(0, 0, 0, 0.25);
}
