const builtin = @import("builtin");
const std = @import("std");

pub const is_web = builtin.arch == builtin.Arch.wasm32;
pub usingnamespace if (is_web) @import("platform/web.zig") else @import("platform/c.zig");

pub extern fn setScore(_: c_int) void;
pub extern fn playAudio(_: [*c]f32, _: c_uint) void;

pub const platform_log = if (is_web) log else std.debug.warn;

pub fn abortReason(comptime format: []const u8, args: ...) noreturn {
    var panic_buf: [255]u8 = undefined;
    const panic_text = std.fmt.bufPrint(panic_buf[0..], format, args) catch unreachable;
    platform_log("{}", panic_text);
    @panic(panic_text);
}
