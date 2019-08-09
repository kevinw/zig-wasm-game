const c = @import("platform.zig");
const std = @import("std");
const os = std.os;
const builtin = @import("builtin");

pub const is_on = if (builtin.mode == builtin.Mode.ReleaseFast) c.GL_FALSE else c.GL_TRUE;

pub fn assertNoErrorFormat(comptime format: []const u8, args: ...) void {
    if (builtin.mode == builtin.Mode.ReleaseFast)
        return;

    const err = c.glGetError();
    if (err != c.GL_NO_ERROR) {
        var buf: [255]u8 = undefined;
        const text = std.fmt.bufPrint(buf[0..], format, args) catch unreachable;
        c.abortReason("GL error: {} - {}\n", err, text);
    }
}

pub fn assertNoErrorWithMessage(s: []const u8) void {
    if (builtin.mode == builtin.Mode.ReleaseFast)
        return;

    const err = c.glGetError();
    if (err != c.GL_NO_ERROR)
        c.abortReason("GL error: {} - {}\n", err, s);
}

pub fn assertNoError() void {
    if (builtin.mode == builtin.Mode.ReleaseFast)
        return;

    const err = c.glGetError();
    if (err != c.GL_NO_ERROR)
        c.abortReason("GL error: {}\n", err);
}
