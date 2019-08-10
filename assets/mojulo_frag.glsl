#version 300 es
precision mediump float;

in vec2 FragTexCoord;
out vec4 FragColor;
uniform vec4 Color;
uniform vec3 camPos;
uniform vec3 playerPos;
uniform float playerScale;
uniform float time;

float randFromVec2(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float rand() { return randFromVec2(FragTexCoord); }

float equation();


void main(void) {
    // OUTPUT
    //float VAL = x*y*sin(time);
    //float VAL = x*time * rand()*40.0;
    float VAL = equation();

    //int color = floatBitsToInt(VAL);
    int color = int(VAL);
    vec3 rgb = vec3(
        (color & 0xff0000) >> 16,
        (color & 0x00ff00) >> 8,
        (color & 0x0000ff) >> 0) / 255.0;
    //FragColor = vec4(R/255.0, G/255.0, B/255.0, 1.0);
    FragColor = vec4(rgb, 1);
}

float equation() {
    float x = FragTexCoord.x * 100.0 + camPos.x;
    float y = FragTexCoord.y * 100.0 + camPos.y;
    float px = x - (playerPos.x * playerScale);
    float py = y - (playerPos.y * playerScale);
    float A = atan(y, x);
    float PA = atan(py, px);
    float r = sqrt(x * x + y * y);
    float pr = sqrt(px * px + py * py);

