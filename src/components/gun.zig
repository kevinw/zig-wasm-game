//capacity=10

usingnamespace @import("../globals.zig");

const GameSession = @import("../session.zig").GameSession;
const Bullet = @import("bullet.zig").Bullet;
const Sprite = @import("sprite.zig").Sprite;
const prefabs = @import("../prefabs.zig");

pub const Gun = struct {
    offset: Vec3 = vec3(0, 0, 0),

    fire_left: bool = false,
    fire_right: bool = false,
    fire_up: bool = false,
    fire_down: bool = false,

    last_fire_time: f32 = -1,
    fire_delay: f32 = 0.19,

    bullet_speed: f32 = 400,
};

pub fn update(gs: *GameSession, gun: *Gun, sprite: *Sprite) bool {
    const now = Time.time;
    if (now - gun.last_fire_time <= gun.fire_delay) return true;

    var dir = vec3(0, 0, 0);
    if (gun.fire_right) dir = dir.add(vec3(1, 0, 0));
    if (gun.fire_left) dir = dir.add(vec3(-1, 0, 0));
    if (gun.fire_up) dir = dir.add(vec3(0, -1, 0));
    if (gun.fire_down) dir = dir.add(vec3(0, 1, 0));
    dir = dir.normalize();

    const fire = prefabs.Bullet.spawn;
    if (dir.length() > 0.000001) {
        dir = dir.multScalar(gun.bullet_speed);
        //log("{} {} {}", dir.x, dir.y, dir.z);

        const origin = sprite.pos.add(gun.offset);
        _ = fire(gs, origin, dir) catch unreachable;
        gun.last_fire_time = now;
    }

    return true;
}
