#version 300 es
precision mediump float;

in vec3 VertexPosition;
in vec2 TexCoord;
out vec2 FragTexCoord;

uniform mat4 MVP;

void main(void) {
    FragTexCoord = TexCoord;
    gl_Position = vec4(VertexPosition, 1.0) * MVP;
}
