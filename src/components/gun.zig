usingnamespace @import("../globals.zig");

const GameSession = @import("../session.zig").GameSession;
const Bullet = @import("bullet.zig").Bullet;
const Sprite = @import("sprite.zig").Sprite;
const prefabs = @import("../prefabs.zig");

pub const Gun = struct {
    fire_left: bool = false,
    fire_right: bool = false,
    fire_up: bool = false,
    fire_down: bool = false,

    last_fire_time: f32 = -1,
    fire_delay: f32 = 0.1,

    bullet_speed: f32 = 400,
};

pub fn update(gs: *GameSession, gun: *Gun, sprite: *Sprite) bool {
    if (Time.time - gun.last_fire_time > gun.fire_delay) {
        const p = sprite.pos;
        const fire = prefabs.Bullet.spawn;

        var dir = vec3(0, 0, 0);
        if (gun.fire_right) dir = dir.add(vec3(1, 0, 0));
        if (gun.fire_left) dir = dir.add(vec3(-1, 0, 0));
        if (gun.fire_up) dir = dir.add(vec3(0, -1, 0));
        if (gun.fire_down) dir = dir.add(vec3(0, 1, 0));
        dir = dir.normalize();

        if (dir.length() > 0.000001) {
            dir = dir.multScalar(gun.bullet_speed);
            //log("{} {} {}", dir.x, dir.y, dir.z);
            _ = fire(gs, sprite.pos, dir) catch unreachable;
        }
    }

    return true;
}
