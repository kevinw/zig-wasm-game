const c = @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("png.h");
    @cInclude("math.h");
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
});

usingnamespace c;
pub usingnamespace c;

pub const std = @import("std");
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;
pub const Window = GLFWwindow;

pub fn initShader(source: []const u8, name: []const u8, kind: c.GLenum) GLuint {
    const shader_id = glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    const source_len = @intCast(c.GLint, source.len);
    c.glShaderSource(shader_id, 1, &source_ptr, &source_len);
    c.glCompileShader(shader_id);

    var ok: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_COMPILE_STATUS, &ok);
    if (ok != 0) return shader_id;

    var error_size: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_INFO_LOG_LENGTH, &error_size);

    const message = allocator.alloc(u8, @intCast(usize, error_size)) catch unreachable;
    c.glGetShaderInfoLog(shader_id, error_size, &error_size, message.ptr);
    panic("Error compiling {} shader:\n{}\n", name, message.ptr);
}

pub fn linkShaderProgram(vertex_id: c.GLuint, fragment_id: c.GLuint, geometry_id: ?c.GLuint) c.GLuint {
    const program_id = c.glCreateProgram();
    c.glAttachShader(program_id, vertex_id);
    c.glAttachShader(program_id, fragment_id);
    if (geometry_id) |geo_id| {
        c.glAttachShader(program_id, geo_id);
    }
    c.glLinkProgram(program_id);

    var ok: c.GLint = undefined;
    c.glGetProgramiv(program_id, c.GL_LINK_STATUS, &ok);
    if (ok != 0) return program_id;

    var error_size: c.GLint = undefined;
    c.glGetProgramiv(program_id, c.GL_INFO_LOG_LENGTH, &error_size);
    const message = allocator.alloc(u8, @intCast(usize, error_size)) catch unreachable;
    c.glGetProgramInfoLog(program_id, error_size, &error_size, message.ptr);
    panic("Error linking shader program: {}\n", message.ptr);
}
