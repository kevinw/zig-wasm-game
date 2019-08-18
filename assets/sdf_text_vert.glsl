#version 300 es
precision mediump float;

in vec2 a_pos;
in vec2 a_texcoord;
out vec2 v_texcoord;

uniform mat4 u_matrix;
uniform vec2 u_texsize;


void main() {
    gl_Position = u_matrix * vec4(a_pos.xy, 0, 1);
    v_texcoord = a_texcoord / u_texsize;
}
