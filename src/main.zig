usingnamespace @import("globals.zig");
const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;
pub const warn = std.debug.warn;

const c = @import("platform.zig");
const game = @import("game.zig");
const Game = game.Game;
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const StaticGeometry = @import("static_geometry.zig").StaticGeometry;
const RawImage = @import("png.zig").RawImage;

const font_png = @embedFile("../assets/font.png");

pub const _log = @import("log.zig").log;

pub extern const NvOptimusEnablement:u32 = 0x00000001;

extern fn errorCallback(err: c_int, description: [*c]const u8) void {
    panic("Error: {}\n", std.mem.toSliceConst(u8, description));
}

extern fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    const down = if (action == c.GLFW_RELEASE) false else true;
    const keycode = @intCast(usize, key);

    if (action != c.GLFW_PRESS) return;
    const t = @ptrCast(*Game, @alignCast(@alignOf(Game), c.glfwGetWindowUserPointer(window).?));

    switch (key) {
        c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(window, c.GL_TRUE),
        c.GLFW_KEY_R => game.restartGame(t),
        c.GLFW_KEY_L => game.logMessage(t),
        c.GLFW_KEY_P => t.cycleEquation(-1),
        c.GLFW_KEY_N => t.cycleEquation(1),
        else => {},
    }
}

extern fn getProcAddress(name: [*c]const u8) ?*c_void {
    var ptr = c.glfwGetProcAddress(name);
    return @intToPtr(?*c_void, @ptrToInt(ptr));
}

fn getKeyCode(keyCode: KeyCode) KeyCode {
    //const keyCodeCInt = @intCast(c_int, keyCode);
    const scancode = c.glfwGetKeyScancode(keyCode);
    if (scancode == -1)
        panic("cannot find scancode for {} {}", keyCode, keyCodeCInt);

    return @intCast(KeyCode, scancode);
}

extern fn framebufferSizeCb(window: ?*c.Window, width: c_int, height: c_int) void {
    c.glViewport(0, 0, width, height);
}

pub fn main() !void {
    const WINDOW_WIDTH = 1200;
    const WINDOW_HEIGHT = 750;

    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == c.GL_FALSE) panic("GLFW init failure\n");
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 2);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, debug_gl.is_on);
    c.glfwWindowHint(c.GLFW_SAMPLES, 4);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_DEPTH_BITS, 0);
    c.glfwWindowHint(c.GLFW_STENCIL_BITS, 8);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_TRUE);

    var window = c.glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, c"Game", null, null) orelse {
        panic("unable to create window\n");
    };
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetFramebufferSizeCallback(window, framebufferSizeCb);
    _ = c.glfwSetKeyCallback(window, keyCallback);
    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);

    if (c.gladLoadGLLoader(getProcAddress) == 0)
        panic("Failed to initialize OpenGL context");

    var t = &game.game_state;
    c.glfwGetFramebufferSize(window, &t.framebuffer_width, &t.framebuffer_height);
    assert(t.framebuffer_width >= WINDOW_WIDTH);
    assert(t.framebuffer_height >= WINDOW_HEIGHT);

    c._setInputWindow(window);

    t.window = window;

    t.all_shaders = AllShaders.create();
    defer t.all_shaders.destroy();

    t.static_geometry = StaticGeometry.create();
    defer t.static_geometry.destroy();

    const font_data = try RawImage.fromPng(font_png);
    t.font.init(font_data, game.font_char_width, game.font_char_height) catch {
        panic("unable to read assets\n");
    };
    defer t.font.deinit();

    //var seed_bytes: [@sizeOf(u64)]u8 = undefined;
    //os.getRandomBytes(seed_bytes[0..]) catch |err| {
    //panic("unable to seed random number generator: {}", err);
    //};
    //const randomSeed = std.mem.readIntNative(u64, &seed_bytes);
    const randomSeed: u64 = 42;
    t.prng = std.rand.DefaultPrng.init(randomSeed);
    t.rand = &t.prng.random;
    c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, t));

    game.init(t);
    debug_gl.assertNoError();

    t.load_resources();
    debug_gl.assertNoError();

    const start_time = c.glfwGetTime();
    var prev_time = start_time;
    while (c.glfwWindowShouldClose(window) == c.GL_FALSE and !t.quit_requested) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        const now_time = c.glfwGetTime();
        const elapsed = now_time - prev_time;
        prev_time = now_time;

        game.nextFrame(t, elapsed);
        game.draw(t);
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    debug_gl.assertNoError();
}
