const builtin = @import("builtin");
const is_web = builtin.arch == builtin.Arch.wasm32;

pub const gamepadLeftStick = if (is_web)
    @import("web_platform_input.zig").gamepadLeftStick
else
    @import("c_platform_input.zig").gamepadLeftStick;
