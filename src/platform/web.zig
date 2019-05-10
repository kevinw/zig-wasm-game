
pub use @import("web/wasm.zig");
// pub use @import("web/dom.zig");
pub use @import("web/canvas.zig");
pub use @import("web/webgl.zig");

const builtin = @import("builtin");
pub const allocator = @import("std").heap.wasm_allocator;

const tetris_state = @import("main.zig").tetris_state;

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    consoleLogS(message.ptr, message.len);
    while (true) {}
}

pub extern fn setScore(_: c_uint) void;
pub extern fn playAudio(_: [*c]f32, _: c_uint) void;

export fn onKeyDown(keyCode: c_int, state: u8) void {
  if (state == 0) return;
  const t = &tetris_state;
  switch (keyCode) {
      KEY_ESCAPE, KEY_P => userTogglePause(t),
      KEY_SPACE => userDropCurPiece(t),
      KEY_DOWN => userCurPieceFall(t),
      KEY_LEFT => userMoveCurPiece(t, -1),
      KEY_RIGHT => userMoveCurPiece(t, 1),
      KEY_UP => userRotateCurPiece(t, 1),
      KEY_SHIFT => userRotateCurPiece(t, -1),
      KEY_R => restartGame(t),
      KEY_CTRL => userSetHoldPiece(t),
      else => {},
  }
}

export fn onKeyUp(button: c_int, x: c_int, y: c_int) void {

}

export fn onMouseDown(button: c_int, x: c_int, y: c_int) void {

}

export fn onMouseUp(button: c_int, x: c_int, y: c_int) void {

}

export fn onMouseMove(x: c_int, y: c_int) void {

}

export fn onInit() void {
    const t = &tetris_state;
    t.framebuffer_width = 500;
    t.framebuffer_height = 660;

    var vertex_array_object: GLuint = undefined;
    glGenVertexArrays(1, &vertex_array_object);
    glBindVertexArray(vertex_array_object);

    t.all_shaders = AllShaders.create() catch abortReason("Shader creation failed");
    t.static_geometry = StaticGeometry.create();
    t.font.init(font_raw, font_char_width, font_char_height) catch unreachable;

    var seed_bytes: [@sizeOf(u64)]u8 = "12341234";
    t.prng = std.rand.DefaultPrng.init(std.mem.readIntNative(u64, &seed_bytes));
    t.rand = &t.prng.random;

    resetProjection(t);

    restartGame(t);

    glClearColor(0.0, 0.0, 0.0, 1.0);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glViewport(0, 0, t.framebuffer_width, t.framebuffer_height);

    debug_gl.assertNoError();
}

var prev_time: c_int = 0;
export fn onAnimationFrame(now_time: c_int) void {
    const t = &tetris_state;
    const elapsed = @intToFloat(f32, now_time - prev_time) / 1000.0;
    prev_time = now_time;

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    nextFrame(t, elapsed);
    draw(t);
}

export fn onDestroy() void {
    const t = &tetris_state;
    t.all_shaders.destroy();
    t.static_geometry.destroy();
    t.font.deinit();
}
