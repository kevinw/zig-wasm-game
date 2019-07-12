usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;

const Sprite = @import("sprite.zig").Sprite;
const Gun = @import("gun.zig").Gun;

pub const Player = struct { // !component
    speed: f32 = 500,
};

pub fn update(gs: *GameSession, player: *Player, sprite: *Sprite, gun: *Gun) bool {
    const speed: f32 = @floatCast(f32, Time.delta_time * player.speed);
    const pos = &sprite.pos;

    const c = @import("../platform.zig");
    const keys = &Input.keys;
    if (keys[c.KEY_RIGHT] or keys[c.KEY_D]) pos.x += speed;
    if (keys[c.KEY_LEFT] or keys[c.KEY_A]) pos.x -= speed;
    if (keys[c.KEY_DOWN] or keys[c.KEY_S]) pos.y += speed;
    if (keys[c.KEY_UP] or keys[c.KEY_W]) pos.y -= speed;

    gun.fire_right = keys[c.KEY_L];
    gun.fire_left = keys[c.KEY_J];
    gun.fire_up = keys[c.KEY_I];
    gun.fire_down = keys[c.KEY_K];

    return true;
}
