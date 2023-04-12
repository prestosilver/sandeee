#version 330 core

in vec3 SCREEN_UV;

out vec4 color;

uniform sampler2D tex;

uniform float time = 0;

uniform float screen_width = 1024;
uniform float screen_height = 600;

// Color bleeding
uniform float color_bleeding = 1.1;
uniform float bleeding_range_x = 3;
uniform float bleeding_range_y = 3;

// Scanline
uniform float lines_distance = 4.0;
uniform float scan_size = 3.0;
uniform float scanline_alpha = 0.85;
uniform float lines_velocity = -2.0;

uniform int crt_enable = 0;
uniform int dither_enable = 0;

#define COLOR_STEPS 8.0
#define GAMMA 2.5
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
    float line_row = floor((uv.y * screen_height/2/scan_size) + mod(time*lines_velocity, lines_distance));
    float n = 1.0 - ceil((mod(line_row,lines_distance)/lines_distance));
    c = c - n*c*(1.0 - scanline_alpha);
    c.a = 1.0;
}


float onOff(float a, float b, float c)
{
    return step(c, sin(time + a*cos(time*b)));
}

float displace(vec2 look)
{
    float y = (look.y-mod(time/4.,1.));
    float window = 1./(1.+50.*y*y);
    return sin(look.y*20. + time)/80.*onOff(4.,2.,.8)*(1.+cos(time*60.))*window;
}

float luma(vec3 color) {
    return (0.2126*color.r + 0.7152*color.g + 0.0722*color.b);
}

vec4 get_color_pos(vec2 pos) {
    vec3 result = texture(tex, pos).rgb;

    if (dither_enable == 0) {
        return vec4(result, 1.0);
    }

    int x = int(mod(pos.x * screen_width / 2, 2.0)); 
    int y = int(mod(pos.y * screen_height / 2, 2.0)); 
    int index = x + y * 2;
    float limit = 0.0;

    if (x < 8) {
        if (index == 0) limit = 0.25;
        if (index == 1) limit = 0.75;
        if (index == 2) limit = 1.00;
        if (index == 3) limit = 0.50;
    }

    vec3 act = round(result * COLOR_STEPS) / COLOR_STEPS;
    vec3 other;
    other.r = act.r < result.r ? act.r + 1.0 / COLOR_STEPS : act.r - 1.0 / COLOR_STEPS;
    other.g = act.g < result.g ? act.g + 1.0 / COLOR_STEPS : act.g - 1.0 / COLOR_STEPS;
    other.b = act.b < result.b ? act.b + 1.0 / COLOR_STEPS : act.b - 1.0 / COLOR_STEPS;

    vec3 mul;

    mul.r = abs((result - act) / (act - other)).r < limit ? 0 : 1.0;
    mul.g = abs((result - act) / (act - other)).g < limit ? 0 : 1.0;
    mul.b = abs((result - act) / (act - other)).b < limit ? 0 : 1.0;

    result = mix(act, other, mul);

    return vec4(result, 1.0);
}

void main()
{
    vec2 xy = (SCREEN_UV.xy + vec2(1)) / 2;

    if (crt_enable == 0) {
        color = get_color_pos(xy);
        return;
    }

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

    xy.x += displace(xy) * 0.125;

    float bar = clamp(exp(1.0 - mod(((xy.y + 1) / 2) + time*0.2, 1.)), 1.0, 1.2) - 0.2;

    float pixel_size_x = 0.5/screen_width*bleeding_range_x;
    float pixel_size_y = 0.5/screen_height*bleeding_range_y;
    vec4 color_left = get_color_pos(xy - vec2(pixel_size_x, pixel_size_y)) * bar;
    vec4 current_color = get_color_pos(xy) * bar;
    color_left = pow(color_left, vec4(GAMMA));
    current_color = pow(current_color, vec4(GAMMA));
    get_color_bleeding(current_color,color_left);
    vec4 c = current_color+color_left;
    get_color_scanline(SCREEN_UV.xy,c,time);

    color = c;
    color = pow(color, vec4(1.0 / GAMMA));
}
