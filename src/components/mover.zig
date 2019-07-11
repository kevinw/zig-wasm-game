usingnamespace @import("../globals.zig");
usingnamespace @import("../math3d.zig");
usingnamespace @import("../session.zig");

const Sprite = @import("sprite.zig").Sprite;

pub const Mover = struct { // !component
    vel: Vec3 = vec3(0, 0, 0),
};

pub fn update(gs: *GameSession, mover: *Mover, sprite: *Sprite) bool {
    const dt = Time.delta_time;
    // log("mover {} {} {}", mover.vel.data[0], mover.vel.data[1], mover.vel.data[2]);
    const old = sprite.pos.data[0];
    sprite.pos.data[0] += mover.vel.data[0] * dt;
    // log("{} += {} = {}", old, mover.vel.data[0] * dt, sprite.pos.data[0]);
    sprite.pos.data[1] += mover.vel.data[1] * dt;
    sprite.pos.data[2] += mover.vel.data[2] * dt;
    return true;
}
