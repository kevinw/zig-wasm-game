usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;

const Sprite = @import("sprite.zig").Sprite;
const Gun = @import("gun.zig").Gun;

pub const Player = struct {
    speed: f32 = 500,
};

pub fn update(gs: *GameSession, player: *Player, sprite: *Sprite, gun: *Gun) bool {
    const speed: f32 = @floatCast(f32, Time.delta_time * player.speed);
    const pos = &sprite.pos;

    const c = @import("../platform.zig");

    if (Input.getKey(c.KEY_RIGHT) or Input.getKey(c.KEY_D)) pos.x += speed;
    if (Input.getKey(c.KEY_LEFT) or Input.getKey(c.KEY_A)) pos.x -= speed;
    if (Input.getKey(c.KEY_DOWN) or Input.getKey(c.KEY_S)) pos.y += speed;
    if (Input.getKey(c.KEY_UP) or Input.getKey(c.KEY_W)) pos.y -= speed;

    gun.fire_right = Input.getKey(c.KEY_L);
    gun.fire_left = Input.getKey(c.KEY_J);
    gun.fire_up = Input.getKey(c.KEY_I);
    gun.fire_down = Input.getKey(c.KEY_K);

    return true;
}
