//capacity=10

const std = @import("std");
usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const c = @import("../platform.zig");

const Transform = @import("transform.zig").Transform;
const Sprite = @import("sprite.zig").Sprite;

pub const Maypole = struct {
    target: *Transform,
};

pub fn update(gs: *GameSession, maypole: *Maypole, player: *Sprite) bool {
    const v = Vec3.zero;
    const dot_product = v.dot(player.pos);
    return true;
}
