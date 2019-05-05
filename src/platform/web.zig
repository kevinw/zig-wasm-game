
pub use @import("web/wasm.zig");
// pub use @import("web/dom.zig");
pub use @import("web/canvas.zig");
pub use @import("web/webgl.zig");

const builtin = @import("builtin");
pub const allocator = @import("std").heap.wasm_allocator;

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    consoleLogS(message.ptr, message.len);
    while (true) {}
}