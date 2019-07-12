usingnamespace @import("../globals.zig");

const GameSession = @import("../session.zig").GameSession;
const Sprite = @import("sprite.zig").Sprite;

pub const Mover = struct {
    vel: Vec3 = vec3(0, 0, 0),
};

pub fn update(gs: *GameSession, mover: *Mover, sprite: *Sprite) bool {
    sprite.pos = sprite.pos.add(mover.vel.multScalar(Time.delta_time));
    return true;
}
