const builtin = @import("builtin");
const bufPrint = @import("std").fmt.bufPrint;

pub const is_web = builtin.arch == builtin.Arch.wasm32;
pub use if (is_web) @import("platform/web.zig") else @import("platform/c.zig");

pub extern fn setScore(_: c_int) void;
pub extern fn playAudio(_: [*c]f32, _: c_uint) void;

pub fn abortReason(comptime format: []const u8, args: ...) noreturn {
    var panic_buf: [255]u8 = undefined;
    const panic_text = bufPrint(panic_buf[0..], format, args) catch unreachable;
    @panic(panic_text);
}