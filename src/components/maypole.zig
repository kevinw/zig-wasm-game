//capacity=10

const std = @import("std");
usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const c = @import("../platform.zig");

const Transform = @import("transform.zig").Transform;

pub const Maypole = struct {
    target: *Transform,
};

pub fn update(gs: *GameSession, maypole: *Maypole) bool {
    return true;
}
