const builtin = @import("builtin");
pub const is_web = builtin.arch == builtin.Arch.wasm32;

pub const warn = if (is_web)
    @import("platform/web.zig").warn
else
    @import("std").debug.warn;
