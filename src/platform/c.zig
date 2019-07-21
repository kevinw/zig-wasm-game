pub usingnamespace @import("native.zig");
usingnamespace @import("native.zig");

const std = @import("std");
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;
pub const warn = std.debug.warn;
pub const Window = GLFWwindow;

pub const KeyCode = c_int;
const K = KeyCode;

pub const KEY_RIGHT: K = GLFW_KEY_RIGHT;
pub const KEY_LEFT: K = GLFW_KEY_LEFT;
pub const KEY_UP: K = GLFW_KEY_UP;
pub const KEY_DOWN: K = GLFW_KEY_DOWN;
pub const KEY_W: K = GLFW_KEY_W;
pub const KEY_A: K = GLFW_KEY_A;
pub const KEY_S: K = GLFW_KEY_S;
pub const KEY_D: K = GLFW_KEY_D;
pub const KEY_I: K = GLFW_KEY_I;
pub const KEY_J: K = GLFW_KEY_J;
pub const KEY_K: K = GLFW_KEY_K;
pub const KEY_L: K = GLFW_KEY_L;
pub const KEY_Q: K = GLFW_KEY_Q;

pub var _inputWindow: *Window = undefined;

pub fn _setInputWindow(window: *Window) void {
    _inputWindow = window;
}

pub fn platformGetKey(keyCode: KeyCode) bool {
    return glfwGetKey(_inputWindow, keyCode) != GLFW_RELEASE;
}

pub fn initShader(source: []const u8, name: []const u8, kind: GLenum) GLuint {
    const shader_id = glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    const source_len = @intCast(GLint, source.len);
    glShaderSource(shader_id, 1, &source_ptr, &source_len);
    glCompileShader(shader_id);

    var ok: GLint = undefined;
    glGetShaderiv(shader_id, GL_COMPILE_STATUS, &ok);
    if (ok != 0) return shader_id;

    var error_size: GLint = undefined;
    glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &error_size);

    const message = allocator.alloc(u8, @intCast(usize, error_size)) catch unreachable;
    glGetShaderInfoLog(shader_id, error_size, &error_size, message.ptr);
    panic("Error compiling {} shader:\n{}\n", name, message.ptr);
}

pub fn linkShaderProgram(vertex_id: GLuint, fragment_id: GLuint, geometry_id: ?GLuint) GLuint {
    const program_id = glCreateProgram();
    glAttachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    if (geometry_id) |geo_id| {
        glAttachShader(program_id, geo_id);
    }
    glLinkProgram(program_id);

    var ok: GLint = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &ok);
    if (ok != 0) return program_id;

    var error_size: GLint = undefined;
    glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &error_size);
    const message = allocator.alloc(u8, @intCast(usize, error_size)) catch unreachable;
    glGetProgramInfoLog(program_id, error_size, &error_size, message.ptr);
    panic("Error linking shader program: {}\n", message.ptr);
}
