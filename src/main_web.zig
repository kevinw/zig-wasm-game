const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
const builtin = @import("builtin");
usingnamespace @import("globals.zig");

// until std has better wasm panic
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    while (true) {
        @breakpoint();
    }
}

pub fn _log(comptime fmt: []const u8, args: ...) void {
    c.log(fmt, args);
}

pub const c = @import("platform.zig");

const game = @import("game.zig");
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const StaticGeometry = @import("static_geometry.zig").StaticGeometry;
const embedImage = @import("png.zig").embedImage;
const RawImage = @import("png.zig").RawImage;

const font_raw = embedImage("../assets/fontx.bin", 576, 128, 32);

inline fn GameState() *game.Game {
    return &game.game_state;
}

export fn onKeyDown(keyCode: c_int, state: u8) void {
    //if (state == 0) return;
    const t = GameState();
    switch (keyCode) {
        c.KEY_ESCAPE, c.KEY_P => game.userTogglePause(t),
        //c.KEY_SPACE => game.userDropCurPiece(t),
        //c.KEY_DOWN => game.userCurPieceFall(t),
        //c.KEY_LEFT => game.userMoveCurPiece(t, -1),
        //c.KEY_RIGHT => game.userMoveCurPiece(t, 1),
        //c.KEY_UP => game.userRotateCurPiece(t, 1),
        //c.KEY_SHIFT => game.userRotateCurPiece(t, -1),
        c.KEY_R => game.restartGame(t),
        //c.KEY_CTRL => game.userSetHoldPiece(t),
        c.KEY_L => game.logMessage(t),
        else => {},
    }

    Input.keys[@intCast(usize, keyCode)] = true;
}

export fn onKeyUp(keyCode: c_int, state: u8) void {
    //if (state != 0) return;
    const t = GameState();
    Input.keys[@intCast(usize, keyCode)] = false;
}

export fn onMouseDown(button: c_int, x: c_int, y: c_int) void {}

export fn onMouseUp(button: c_int, x: c_int, y: c_int) void {}

export fn onMouseMove(x: c_int, y: c_int) void {}

fn reverseImageY(bytes: []u8, pitch: u32) ![]u8 {
    const new_bytes = try c.allocator.alloc(u8, bytes.len);
    const num_rows = bytes.len / pitch;

    var i: u32 = 0;
    while (i < num_rows) : (i += 1) {
        const row_start = i * pitch;
        const new_row_start = (num_rows - i - 1) * pitch;

        const dest = new_bytes[new_row_start .. new_row_start + pitch];
        const src = bytes[row_start .. row_start + pitch];

        std.mem.copy(u8, dest, src);
    }

    //pub fn copy(comptime T: type, dest: []T, source: []const T) void {
    return new_bytes;
}

export fn onFetch(width: c_uint, height: c_uint, bytes_ptr: c_uint, bytes_len: c_uint) void {
    //c.log("FROM WASM ON FETCH {} {}", bytes_ptr, bytes_len);
    if (bytes_len == 0 or bytes_ptr == 0) {
        c.log("error: bytes_len or bytes_ptr was zero");
        return;
    }

    var rawSlice = @intToPtr([*]u8, bytes_ptr);
    var slice = rawSlice[0..bytes_len];
    defer c.allocator.free(slice);

    const pitch = bytes_len / height;

    var flippedSlice = reverseImageY(slice, pitch) catch unreachable;
    defer c.allocator.free(flippedSlice);

    //c.log("got slice: '{}'", slice.len);
    const raw_image = RawImage{
        .width = width,
        .height = height,
        .pitch = pitch,
        .raw = flippedSlice,
    };

    GameState().player.init(raw_image, 48, 48) catch |err| {
        c.log("error initializing player sprite {}", err);
    };
}

var vertex_array_object: c.GLuint = undefined;
export fn onInit() void {
    const t = GameState();
    t.framebuffer_width = 800;
    t.framebuffer_height = 450;

    c.glGenVertexArrays(1, &vertex_array_object);
    c.glBindVertexArray(vertex_array_object);

    t.all_shaders = AllShaders.create();
    t.static_geometry = StaticGeometry.create();
    t.font.init(font_raw, game.font_char_width, game.font_char_height) catch unreachable;

    t.debug_console = @typeOf(t.debug_console).init(c.allocator);

    t.prng = std.rand.DefaultPrng.init(@intCast(u64, c.getRandomSeed()));
    t.rand = &t.prng.random;

    game.resetProjection(t);

    game.restartGame(t);

    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    c.glViewport(0, 0, t.framebuffer_width, t.framebuffer_height);

    debug_gl.assertNoError();

    fetchBytes("assets/face.png");
}

pub fn fetchBytes(url: []const u8) void {
    c.fetchBytes(url.ptr, url.len);
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
