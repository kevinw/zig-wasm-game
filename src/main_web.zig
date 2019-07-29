const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
const builtin = @import("builtin");
usingnamespace @import("globals.zig");
const fetch = @import("fetch.zig");

// Until std has better WASM panic
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    while (true) {
        @breakpoint();
    }
}

pub fn _log(comptime fmt: []const u8, args: ...) void {
    c.log(fmt, args);
}

pub const warn = _log;

pub const c = @import("platform.zig");

const game = @import("game.zig");
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const StaticGeometry = @import("static_geometry.zig").StaticGeometry;
const embedImage = @import("png.zig").embedImage;
const RawImage = @import("png.zig").RawImage;

const font_raw = embedImage("../assets/fontx.bin", 576, 128, 32);

pub inline fn GameState() *game.Game {
    return &game.game_state;
}

export fn onEquation(eq_ptr: c_uint, eq_len: c_uint) void {
    var equation_str = @intToPtr([*]u8, eq_ptr)[0..eq_len];
    defer c.allocator.free(equation_str);

    game.update_equation(GameState(), equation_str);
}

export fn onKeyDown(keyCode: c_int, state: u8, repeat: c_int) void {
    //if (state == 0) return;
    if (repeat > 0) return;
    const t = GameState();
    switch (keyCode) {
        c.KEY_ESCAPE => game.userTogglePause(t),
        c.KEY_R => game.restartGame(t),
        c.KEY_L => game.logMessage(t),
        c.KEY_N => t.cycleEquation(1),
        c.KEY_P => t.cycleEquation(-1),
        else => {},
    }

    c.wasm_keys[@intCast(usize, keyCode)] = true;
}

export fn onKeyUp(keyCode: c_int, state: u8) void {
    //if (state != 0) return;
    const t = GameState();
    c.wasm_keys[@intCast(usize, keyCode)] = false;
}

export fn onMouseDown(button: c_int, x: c_int, y: c_int) void {}

export fn onMouseUp(button: c_int, x: c_int, y: c_int) void {}

export fn onMouseMove(x: c_int, y: c_int) void {}

var vertex_array_object: c.GLuint = undefined;

export fn onFetch(width: c_uint, height: c_uint, bytes_ptr: c_uint, bytes_len: c_uint, token: c_uint) void {
    var bytes = @intToPtr([*]u8, bytes_ptr)[0..bytes_len];
    defer c.allocator.free(bytes);

    fetch.onFetch(width, height, bytes, token);
}

export fn onInit(width: c_uint, height: c_uint) void {
    const t = GameState();
    t.framebuffer_width = @intCast(c_int, width);
    t.framebuffer_height = @intCast(c_int, height);

    c.glGenVertexArrays(1, &vertex_array_object);
    c.glBindVertexArray(vertex_array_object);

    t.all_shaders = AllShaders.create();
    t.static_geometry = StaticGeometry.create();
    t.font.init(font_raw, game.font_char_width, game.font_char_height) catch unreachable;

    t.prng = std.rand.DefaultPrng.init(@intCast(u64, c.getRandomSeed()));
    t.rand = &t.prng.random;

    game.resetProjection(t);
    game.init(t);

    debug_gl.assertNoError();

    t.load_resources();
}

var prev_time: c_int = 0;
export fn onAnimationFrame(now_time: c_int) void {
    const elapsed = @intToFloat(f32, now_time - prev_time) / 1000.0;
    prev_time = now_time;

    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

    const state = GameState();
    game.nextFrame(state, elapsed);
    game.draw(state);
}

export fn onDestroy() void {
    const t = GameState();
    t.all_shaders.destroy();
    t.static_geometry.destroy();
    t.font.deinit();
    //t.player.deinit();
    c.glDeleteVertexArrays(1, &vertex_array_object);
}
