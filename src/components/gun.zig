usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");
usingnamespace @import("../math3d.zig");

const c = @import("../platform.zig");
const Bullet = @import("bullet.zig").Bullet;
const Sprite = @import("sprite.zig").Sprite;
const prefabs = @import("../prefabs.zig");

pub const Gun = struct { // !component
    fire_left: bool = false,
    fire_right: bool = false,
    fire_up: bool = false,
    fire_down: bool = false,

    last_fire_time: f32 = -1,
    fire_delay: f32 = 0.1,

    bullet_speed: f32 = 400,
};

const fire = prefabs.Bullet.spawn;

pub fn update(gs: *GameSession, gun: *Gun, sprite: *Sprite) bool {
    if (Time.time - gun.last_fire_time > gun.fire_delay) {
        const p = sprite.pos;
        const spd = gun.bullet_speed;
        if (gun.fire_right) _ = fire(gs, p, vec3(1 * spd, 0, 0)) catch unreachable;
        if (gun.fire_left) _ = fire(gs, p, vec3(-1 * spd, 0, 0)) catch unreachable;
        if (gun.fire_up) _ = fire(gs, p, vec3(0, -1 * spd, 0)) catch unreachable;
        if (gun.fire_down) _ = fire(gs, p, vec3(0, 1 * spd, 0)) catch unreachable;
    }

    return true;
}
