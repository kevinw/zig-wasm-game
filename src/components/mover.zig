usingnamespace @import("../globals.zig");

const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const Mover = struct {
    vel: Vec3 = vec3(0, 0, 0),
};

pub fn update(gs: *GameSession, mover: *Mover, transform: *Transform) bool {
    transform.position.addInPlace(mover.vel.multScalar(Time.delta_time));
    return true;
}
