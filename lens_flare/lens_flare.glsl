#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, binding = 0, set = 0) uniform image2D screen_tex;
layout(binding = 0, set = 1) uniform sampler2D lens_flare_tex;

layout(push_constant, std430) uniform Params {
    vec2 screen_size;
    vec2 sun_screen_position;
    float sun_dot;
} params;


void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    // Screen size
    vec2 size = params.screen_size;
    

    if(pixel.x >= size.x || pixel.y >= size.y) return;

    vec4 screen_texture = imageLoad(screen_tex, pixel);

    vec2 offsets[5] = vec2[5](vec2(0.0, 0.0), ivec2(1.0, 0.0), ivec2(0.0, 1.0), ivec2(-1.0, 0.0), ivec2(0.0, -1.0));
    
    float occlusion = 0.0;
    
    for(int i = 0; i < offsets.length(); i++){
        occlusion += imageLoad(screen_tex, ivec2(params.sun_screen_position + offsets[i] * 8.0)).a;
    }
    

    occlusion /= offsets.length();
    
    float flare = 0.0;

    int res = 7;

    float campled_dot = clamp(params.sun_dot, 0.0, 1.0);
    float intensity = clamp(1.0 - sin(campled_dot * 3.14), 0.0, 1.0);

    for(int i = 0; i < res; i++){
        float percent = float(i + 1) / float(res + 1);
        vec2 uv = pixel / size;
        vec2 p = params.sun_screen_position / size;
        uv -= p;
        uv += (p - vec2(0.5)) * percent * 2.0 * sin(percent * 2.0);
        uv *= 10.0 - sin(percent * 20.0) * (intensity) * 5.0;
        uv.x *= size.x / size.y;
        uv += 0.5;
        flare += texture(lens_flare_tex, uv).g * intensity ;
    }
    
    vec2 uv = pixel / size;
    vec2 p = params.sun_screen_position / size;
    uv -= p;
    uv *= 3.0 - intensity * 1;
    uv.x *= size.x / size.y;
    uv += 0.5;
    flare += texture(lens_flare_tex, uv).r * intensity * (1.0 - screen_texture.a);

    flare *= (1.0 - occlusion) * campled_dot;

    screen_texture.rgb += screen_texture.rgb * screen_texture.rgb * 2.0 * flare + flare * vec3(1.0, 0.8, 0.0) * 0.05;
    imageStore(screen_tex, pixel, screen_texture);
}