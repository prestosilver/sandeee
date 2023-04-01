#version 330 core

in vec3 SCREEN_UV;

out vec4 color;

uniform sampler2D tex;

uniform float time = 0;

uniform float screen_width = 1024;
uniform float screen_height = 600;

// Color bleeding
uniform float color_bleeding = 1.2;
uniform float bleeding_range_x = 1;
uniform float bleeding_range_y = 1;
// Scanline
uniform float lines_distance = 4.0;
uniform float scan_size = 2.0;
uniform float scanline_alpha = 0.95;
uniform float lines_velocity = 30.0;

#define distortion 0.1

vec2 distort(vec2 coord, const vec2 ratio)
{
	float offsety = 1.0 - ratio.y;
	coord.y -= offsety;
	coord /= ratio;

	vec2 cc = coord - 0.5;
	float dist = dot(cc, cc) * distortion;
	vec2 result = coord + cc * (1.0 + dist) * dist;

	result *= ratio;
	result.y += offsety;

	return result;
}

void get_color_bleeding(inout vec4 current_color,inout vec4 color_left){
    current_color = current_color*vec4(color_bleeding,0.5,1.0-color_bleeding,1);
    color_left = color_left*vec4(1.0-color_bleeding,0.5,color_bleeding,1);
}

void get_color_scanline(vec2 uv,inout vec4 c,float time){
    float line_row = floor((uv.y * screen_height/scan_size) + mod(time*lines_velocity, lines_distance));
    float n = 1.0 - ceil((mod(line_row,lines_distance)/lines_distance));
    c = c - n*c*(1.0 - scanline_alpha);
    c.a = 1.0;
}

void main()
{
    vec2 xy = (SCREEN_UV.xy + vec2(1)) / 2;

    float d = length(xy);
    if(d < 1.5){
        xy = distort(xy, vec2(1));
    }
    else{
        xy = SCREEN_UV.xy;
    }

    if (xy.x < 0 || xy.y < 0) {
        color = vec4(0, 0, 0, 1);
        return;
    }

    if (xy.x > 1 || xy.y > 1) {
        color = vec4(0, 0, 0, 1);
        return;
    }

    float pixel_size_x = 1.0/screen_width*bleeding_range_x;
    float pixel_size_y = 1.0/screen_height*bleeding_range_y;
    vec4 color_left = texture(tex,xy - vec2(pixel_size_x, pixel_size_y));
    vec4 current_color = texture(tex,xy);
    get_color_bleeding(current_color,color_left);
    vec4 c = current_color+color_left;
    get_color_scanline(xy,c,time);
    color = c;
}
