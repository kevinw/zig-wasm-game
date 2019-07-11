//const gbe = @import("../oxid/gbe.zig");
const gbe = @import("gbe");
const input = @import("input.zig");
usingnamespace @import("math3d.zig");

pub const EventInput = struct {
    command: input.Command,
    down: bool,
};

pub usingnamespace @import("components_auto.zig");
