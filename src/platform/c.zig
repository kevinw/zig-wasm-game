const c = @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("png.h");
    @cInclude("math.h");
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
});

pub use c;

const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;

const tetris = @import("../main.zig");
const Tetris = tetris.Tetris;
const debug_gl = @import("../debug_gl.zig");
const AllShaders = @import("../all_shaders.zig").AllShaders;
const StaticGeometry = @import("../static_geometry.zig").StaticGeometry;
const RawImage = @import("../png.zig").RawImage;

const font_png = @embedFile("../../assets/font.png");

extern fn errorCallback(err: c_int, description: [*c]const u8) void {
    panic("Error: {}\n", description);
}

extern fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    if (action != c.GLFW_PRESS) return;
    const t = @ptrCast(*Tetris, @alignCast(@alignOf(Tetris), c.glfwGetWindowUserPointer(window).?));

    switch (key) {
        c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(window, c.GL_TRUE),
        c.GLFW_KEY_SPACE => tetris.userDropCurPiece(t),
        c.GLFW_KEY_DOWN => tetris.userCurPieceFall(t),
        c.GLFW_KEY_LEFT => tetris.userMoveCurPiece(t, -1),
        c.GLFW_KEY_RIGHT => tetris.userMoveCurPiece(t, 1),
        c.GLFW_KEY_UP => tetris.userRotateCurPiece(t, 1),
        c.GLFW_KEY_LEFT_SHIFT, c.GLFW_KEY_RIGHT_SHIFT => tetris.userRotateCurPiece(t, -1),
        c.GLFW_KEY_R => tetris.restartGame(t),
        c.GLFW_KEY_P => tetris.userTogglePause(t),
        c.GLFW_KEY_LEFT_CONTROL, c.GLFW_KEY_RIGHT_CONTROL => tetris.userSetHoldPiece(t),
        else => {},
    }
}

pub fn main() !void {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == c.GL_FALSE) {
        panic("GLFW init failure\n");
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 2);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, debug_gl.is_on);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_DEPTH_BITS, 0);
    c.glfwWindowHint(c.GLFW_STENCIL_BITS, 8);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_FALSE);

    var window = c.glfwCreateWindow(tetris.window_width, tetris.window_height, c"Tetris", null, null) orelse {
        panic("unable to create window\n");
    };
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetKeyCallback(window, keyCallback);
    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);

    // create and bind exactly one vertex array per context and use
    // c.glVertexAttribPointer etc every frame.
    var vertex_array_object: c.GLuint = undefined;
    c.glGenVertexArrays(1, &vertex_array_object);
    c.glBindVertexArray(vertex_array_object);
    defer c.glDeleteVertexArrays(1, &vertex_array_object);

    var t = &tetris.tetris_state;
    c.glfwGetFramebufferSize(window, &t.framebuffer_width, &t.framebuffer_height);
    assert(t.framebuffer_width >= tetris.window_width);
    assert(t.framebuffer_height >= tetris.window_height);

    t.window = window;

    t.all_shaders = try AllShaders.create();
    defer t.all_shaders.destroy();

    t.static_geometry = StaticGeometry.create();
    defer t.static_geometry.destroy();

    const font_data = try RawImage.fromPng(font_png);
    t.font.init(font_data, tetris.font_char_width, tetris.font_char_height) catch {
        panic("unable to read assets\n");
    };
    defer t.font.deinit();

    var seed_bytes: [@sizeOf(u64)]u8 = undefined;
    os.getRandomBytes(seed_bytes[0..]) catch |err| {
        panic("unable to seed random number generator: {}", err);
    };
    t.prng = std.rand.DefaultPrng.init(std.mem.readIntNative(u64, &seed_bytes));
    t.rand = &t.prng.random;

    tetris.resetProjection(t);

    tetris.restartGame(t);

    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    c.glViewport(0, 0, t.framebuffer_width, t.framebuffer_height);
    c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, t));

    debug_gl.assertNoError();

    const start_time = c.glfwGetTime();
    var prev_time = start_time;

    while (c.glfwWindowShouldClose(window) == c.GL_FALSE) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        const now_time = c.glfwGetTime();
        const elapsed = now_time - prev_time;
        prev_time = now_time;

        tetris.nextFrame(t, elapsed);

        tetris.draw(t);
        c.glfwSwapBuffers(window);

        c.glfwPollEvents();
    }

    debug_gl.assertNoError();
}

pub fn initShader(source: []const u8, name: [*]const u8, kind: c.GLenum) !c.GLuint {
    const shader_id = c.glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    const source_len = @intCast(c.GLint, source.len);
    c.glShaderSource(shader_id, 1, &source_ptr, &source_len);
    c.glCompileShader(shader_id);

    var ok: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_COMPILE_STATUS, &ok);
    if (ok != 0) return shader_id;

    var error_size: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_INFO_LOG_LENGTH, &error_size);

    const message = try allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetShaderInfoLog(shader_id, error_size, &error_size, message.ptr);
    panic("Error compiling {} shader:\n{}\n", name, message.ptr);
}

pub fn linkShaderProgram(vertex_id: c.GLuint, fragment_id: c.GLuint, geometry_id: ?c.GLuint) !c.GLuint {
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
    const message = try allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetProgramInfoLog(program_id, error_size, &error_size, message.ptr);
    panic("Error linking shader program: {}\n", message.ptr);
}