#version 330 core

in vec2 texCoords;
in vec4 tintColor;

out vec4 color;

uniform sampler2D tex;
uniform sampler2D palette;

void main() {
  color = tintColor * texture(tex, texCoords);

  //vec4 new_color = vec4(0);

  //new_color.r = round(color.r * 8) / 8;
  //new_color.g = round(color.g * 8) / 8;
  //new_color.b = round(color.b * 4) / 4;
  //new_color.a = color.a;

  //color = new_color;
}
