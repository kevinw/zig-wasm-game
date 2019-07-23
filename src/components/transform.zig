usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");

pub const Transform = struct {
    position: Vec3 = Vec3.zero,
    rotation: Vec3 = Vec3.zero,
    scale: Vec3 = Vec3.one,
};

pub fn update(gs: *GameSession, transform: *Transform) bool {
    return true;
}
