//const gbe = @import("../oxid/gbe.zig");
const gbe = @import("gbe");

const input = @import("input.zig");

usingnamespace @import("math3d.zig");

pub const EventInput = struct {
    command: input.Command,
    down: bool,
};

pub const Player = struct {
    pos: Vec3,
    speed: f32 = 500,
};

pub const Sprite = @import("components/sprite.zig").Sprite;
