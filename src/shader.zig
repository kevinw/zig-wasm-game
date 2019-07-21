usingnamespace @import("platform.zig");

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
