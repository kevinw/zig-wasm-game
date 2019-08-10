//capacity=4

const std = @import("std");
usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const c = @import("../platform.zig");

const Sprite = @import("sprite.zig").Sprite;
const Gun = @import("gun.zig").Gun;
const Transform = @import("transform.zig").Transform;

const platform_input = @import("../platform/platform_input.zig");

pub const Player = struct {
    speed: f32 = 500,
};

pub fn update(gs: *GameSession, player: *Player, sprite: *Sprite, xform: *Transform, gun: *Gun) bool {
    const speed: f32 = @floatCast(f32, Time.delta_time * player.speed);

    var delta = Vec2.zero;

    if (Input.getKey(c.KEY_RIGHT) or Input.getKey(c.KEY_D)) delta.x += speed;
    if (Input.getKey(c.KEY_LEFT) or Input.getKey(c.KEY_A)) delta.x -= speed;
    if (Input.getKey(c.KEY_DOWN) or Input.getKey(c.KEY_S)) delta.y += speed;
    if (Input.getKey(c.KEY_UP) or Input.getKey(c.KEY_W)) delta.y -= speed;

    const leftStick = platform_input.gamepadLeftStick();
    delta.x += speed * leftStick.x;
    delta.y += speed * leftStick.y;

    if (delta.length() > 0.0001) {
        delta = delta.normalize().scale(std.math.min(speed, delta.length()));
    }

    xform.position.x += delta.x;
    xform.position.y += delta.y;

    //sprite.pos.x += delta.x;
    //sprite.pos.y += delta.y;

    gun.fire_right = Input.getKey(c.KEY_L);
    gun.fire_left = Input.getKey(c.KEY_J);
    gun.fire_up = Input.getKey(c.KEY_I);
    gun.fire_down = Input.getKey(c.KEY_K);

    @import("../game.zig").game_state.debug_log("foo");


    return true;
}
