const std = @import("std");
const os = std.os;
const c = @import("platform.zig");
const math3d = @import("math3d.zig");
const debug_gl = @import("debug_gl.zig");
const Vec4 = math3d.Vec4;
const Vec3 = math3d.Vec3;
const Mat4x4 = math3d.Mat4x4;
const allocator = platform.allocator;
const log = @import("log.zig").log;

const shader = @import("shader.zig");

pub const AllShaders = struct {
    primitive: ShaderProgram,
    primitive_attrib_position: c.GLint,
    primitive_uniform_mvp: c.GLint,
    primitive_uniform_color: c.GLint,

    texture: ShaderProgram,
    texture_attrib_tex_coord: c.GLint,
    texture_attrib_position: c.GLint,
    texture_uniform_mvp: c.GLint,
    texture_uniform_tex: c.GLint,
    texture_uniform_tint: c.GLint,

    pub fn create() AllShaders {
        var as: AllShaders = undefined;

        var vertex_array_object: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vertex_array_object);
        c.glBindVertexArray(vertex_array_object);

        as.primitive = ShaderProgram.create(
            \\#version 300 es
            \\precision mediump float;
            \\in vec3 VertexPosition;
            \\uniform mat4 MVP;
            \\void main(void) {
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
            \\#version 300 es
            \\precision mediump float;
            \\out vec4 FragColor;
            \\uniform vec4 Color;
            \\void main(void) {
            \\    FragColor = Color;
            \\}
        , null);

        as.primitive_attrib_position = as.primitive.attribLocation("VertexPosition\x00");
        as.primitive_uniform_mvp = as.primitive.uniformLoc("MVP");
        as.primitive_uniform_color = as.primitive.uniformLoc("Color");

        as.texture = ShaderProgram.create(
            \\#version 300 es
            \\precision mediump float;
            \\in vec3 VertexPosition;
            \\in vec2 TexCoord;
            \\out vec2 FragTexCoord;
            \\uniform mat4 MVP;
            \\void main(void) {
            \\    FragTexCoord = TexCoord;
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
            \\#version 300 es
            \\precision mediump float;
            \\in vec2 FragTexCoord;
            \\out vec4 FragColor;
            \\uniform sampler2D Tex;
            \\uniform vec4 Tint;
            \\void main(void) {
            \\    FragColor = texture(Tex, FragTexCoord) * Tint;
            \\}
        , null);

        as.texture_attrib_tex_coord = as.texture.attribLocation("TexCoord\x00");
        as.texture_attrib_position = as.texture.attribLocation("VertexPosition\x00");

        as.texture_uniform_mvp = as.texture.uniformLoc("MVP");
        as.texture_uniform_tex = as.texture.uniformLoc("Tex");
        as.texture_uniform_tint = as.texture.uniformLoc("Tint");

        debug_gl.assertNoError();

        return as;
    }

    pub fn destroy(as: *AllShaders) void {
        as.primitive.destroy();
        as.texture.destroy();
    }
};

pub const ShaderProgram = struct {
    const Self = @This();

    program_id: c.GLuint = 0,
    vertex_id: c.GLuint,
    fragment_id: c.GLuint,
    maybe_geometry_id: ?c.GLuint,

    pub fn bind(sp: ShaderProgram) void {
        c.glUseProgram(sp.program_id);
    }

    pub fn attribLoc(sp: ShaderProgram, comptime name: []const u8) c.GLint {
        const name_cstr = name ++ "\x00";
        return sp.attribLocation(name_cstr);
    }

    pub fn uniformLoc(sp: ShaderProgram, comptime name: []const u8) c.GLint {
        const name_cstr = name ++ "\x00";
        return sp.uniformLocation(name_cstr);
    }

    pub fn attribLocation(sp: ShaderProgram, name: []const u8) c.GLint {
        const id = if (c.is_web)
            c.glGetAttribLocation(sp.program_id, name.ptr, name.len - 1)
        else
            c.glGetAttribLocation(sp.program_id, name.ptr);

        if (id == -1) c.abortReason("invalid attrib: {}\n", name);
        return id;
    }

    pub fn uniformLocation(sp: ShaderProgram, name: []const u8) c.GLint {
        if (c.is_web and name[name.len - 1] != 0) log("warning: last byte should be null: {}", name);

        const id = if (c.is_web)
            c.glGetUniformLocation(sp.program_id, name.ptr, name.len - 1)
        else
            c.glGetUniformLocation(sp.program_id, name.ptr);

        //if (id == -1) c.abortReason("invalid uniform: {}\n", name);

        return id;
    }
    
    fn setUniform(sp: *Self, uniform: var, value: var) void {
        c.glUseProgram(sp.program_id);
        sp.setUniformWithOptional(uniform, value, false);
    }

    fn setUniformMaybe(sp: *Self, uniform: var, value: var) void {
        c.glUseProgram(sp.program_id);
        sp.setUniformWithOptional(uniform, value, true);
    }

    fn setUniformWithOptional(sp: ShaderProgram, uniform: var, value: var, optional: bool) void {
        const uniform_id: c.GLint = switch (@typeInfo(@typeOf(uniform))) {
            .Array => |a| blk: {
                // TODO: use a max size so we don't codegen a new copy of this
                // func for every string length
                var buf: [a.len + 1]u8 = undefined;
                std.mem.copy(u8, buf[0..], uniform);
                buf[a.len] = '\x00';
                break :blk if (c.is_web)
                    c.glGetUniformLocation(sp.program_id, &buf, buf.len - 1)
                else
                    c.glGetUniformLocation(sp.program_id, &buf);
            },
            .Int => |i| uniform,
            else => @compileError("unexpected type for uniform: " ++ @typeOf(uniform).name),
        };

        if (optional and uniform_id == 0) {
            log("ignoring {}", uniform);
            return;
        }

        switch (@typeId(@typeOf(value))) {
            .Int => c.glUniform1i(uniform_id, value),
            .Float => c.glUniform1f(uniform_id, value),
            .Struct => {
                switch (@typeOf(value)) {
                    Vec3 => {
                        sp.setUniformVec3(uniform_id, value);
                    },
                    Vec4 => {
                        sp.setUniformVec4(uniform_id, value);
                    },
                    Mat4x4 => {
                        c.glUniformMatrix4fv(uniform_id, 1, c.GL_FALSE, value.data[0][0..].ptr);
                    },
                    else => {
                        @compileError("invalid type to setUniform");
                    },
                }
            },
            else => @compileError("invalid type to setUniform"),
        }

        debug_gl.assertNoErrorFormat("error setting uniform '{}' (location {})", uniform, uniform_id);
    }

    pub fn setUniformInt(sp: ShaderProgram, uniform_id: c.GLint, value: c_int) void {
        c.glUniform1i(uniform_id, value);
    }

    pub fn setUniformFloat(sp: ShaderProgram, uniform_id: c.GLint, value: f32) void {
        c.glUniform1f(uniform_id, value);
    }

    pub fn setUniformFloatByName(sp: ShaderProgram, comptime name: []const u8, value: f32) void {
        const uniformId = sp.uniformLoc(name);
        if (uniformId != -1)
            sp.setUniformFloat(uniformId, value);
    }

    pub fn setUniformVec3(sp: ShaderProgram, uniform_id: c.GLint, value: math3d.Vec3) void {
        if (c.is_web) {
            c.glUniform3fv(uniform_id, value.x, value.y, value.z);
        } else {
            var v = value;
            c.glUniform3fv(uniform_id, 1, v.ptr());
        }
    }

    pub fn setUniformVec4(sp: ShaderProgram, uniform_id: c.GLint, value: Vec4) void {
        if (c.is_web) {
            c.glUniform4fv(uniform_id, value.x, value.y, value.z, value.w);
        } else {
            var v = value;
            c.glUniform4fv(uniform_id, 1, v.ptr());
        }
    }

    pub fn setUniformVec3ByName(sp: ShaderProgram, comptime name: []const u8, value: Vec3) void {
        const location = sp.uniformLoc(name);
        if (location != -1) {
            sp.setUniformVec3(location, value);
        } else {
            log("location for {}: {}", name, location);
        }

        debug_gl.assertNoErrorWithMessage("error getting uniform " ++ name);
    }

    pub fn setUniformVec4ByName(sp: ShaderProgram, comptime name: []const u8, value: Vec4) void {
        const location = sp.uniformLoc(name);
        if (location != -1) sp.setUniformVec4(location, value);
    }

    pub fn setUniformMat4x4(sp: ShaderProgram, uniform_id: c.GLint, value: Mat4x4) void {
        c.glUniformMatrix4fv(uniform_id, 1, c.GL_FALSE, value.data[0][0..].ptr);
    }

    pub fn setUniformMat4x4ByName(sp: ShaderProgram, comptime name: []const u8, value: Mat4x4) void {
        const location = sp.uniformLoc(name);
        if (location != -1) c.glUniformMatrix4fv(location, 1, c.GL_FALSE, value.data[0][0..].ptr);
    }

    pub const UniformPair = struct {
        name: []const u8,
        type: i32,
    };

    pub const UniformList = std.ArrayList(UniformPair);

    fn getGLEnumString(val: c.GLenum) []const u8 {
        return switch (val) {
            c.GL_FLOAT => "GL_FLOAT",
            c.GL_FLOAT_VEC2 => "GL_FLOAT_VEC2",
            c.GL_FLOAT_VEC3 => "GL_FLOAT_VEC3",
            c.GL_FLOAT_VEC4 => "GL_FLOAT_VEC4",
            else => "unknown (TODO: impl)",
        };
    }

    pub fn getUniforms(self: *const Self, list: *UniformList) void {
        var count:c_int = -1;
        c.glGetProgramiv(self.program_id, c.GL_ACTIVE_ATTRIBUTES, &count);
        if (count == -1) {
            log("getUniforms didn't return anything");
            return;
        }
        var i:c_int = 0;
        while (i < count) : (i += 1) {
            var name: [100]u8 = [_]u8 {'\x00'} ** 100; // TODO
            var size: c_int = 0;
            var gltype: c_uint = 0;
            var len: c_int = 0;
            c.glGetActiveUniform(self.program_id, @intCast(c_uint, i), 100, &len, &size, &gltype, &name);
        }
    }

    pub fn create(
        vertex_source: []const u8,
        frag_source: []const u8,
        maybe_geometry_source: ?[]u8,
    ) ShaderProgram {
        var sp: ShaderProgram = undefined;
        sp.vertex_id = c.initShader(vertex_source, "vertex" ++ "\x00", c.GL_VERTEX_SHADER);
        sp.fragment_id = c.initShader(frag_source, "fragment" ++ "\x00", c.GL_FRAGMENT_SHADER);
        sp.program_id = c.linkShaderProgram(sp.vertex_id, sp.fragment_id, null);
        if (maybe_geometry_source) |geo_source| {
            unreachable;
        }
        debug_gl.assertNoError();
        return sp;
    }

    pub fn destroy(sp: *ShaderProgram) void {
        if (sp.maybe_geometry_id) |geo_id| {
            c.glDetachShader(sp.program_id, geo_id);
        }

        if (sp.program_id > 0) {
            c.glDetachShader(sp.program_id, sp.fragment_id);
            c.glDetachShader(sp.program_id, sp.vertex_id);
        }

        if (sp.maybe_geometry_id) |geo_id| {
            c.glDeleteShader(geo_id);
        }
        if (sp.fragment_id > 0) c.glDeleteShader(sp.fragment_id);
        if (sp.vertex_id > 0) c.glDeleteShader(sp.vertex_id);

        if (sp.program_id > 0)
            c.glDeleteProgram(sp.program_id);
    }
};
