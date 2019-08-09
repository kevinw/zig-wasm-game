const builtin = @import("builtin");
const std = @import("std");

pub const is_web = builtin.arch == builtin.Arch.wasm32;
pub const NEEDS_Y_FLIP = is_web;

pub usingnamespace if (is_web) @import("platform/web.zig") else @import("platform/c.zig");

pub extern fn setScore(_: c_int) void;
pub extern fn playAudio(_: [*c]f32, _: c_uint) void;

fn stdDebugLog(comptime fmt: []const u8, args: ...) void {
    std.debug.warn(fmt, args);
    std.debug.warn("\n");
}

pub const platform_log = if (is_web) log else stdDebugLog;

pub fn abortReason(comptime format: []const u8, args: ...) noreturn {
    var panic_buf: [255]u8 = undefined;
    const panic_text = std.fmt.bufPrint(panic_buf[0..], format, args) catch unreachable;
    platform_log("{}", panic_text);
    @panic(panic_text);
}
