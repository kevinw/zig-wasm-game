const std = @import("std");
usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const c = @import("../platform.zig");

const Sprite = @import("sprite.zig").Sprite;
const Gun = @import("gun.zig").Gun;

pub const Player = struct {
    speed: f32 = 500,
};

const dead_zone = Vec2.init(0.09, 0.09);

fn gamepadLeftStick() Vec2 {
    var state: c.GLFWgamepadstate = undefined;
    if (c.glfwGetGamepadState(0, &state) != 0) {
        var axes = Vec2.init(
            state.axes[c.GLFW_GAMEPAD_AXIS_LEFT_X],
            state.axes[c.GLFW_GAMEPAD_AXIS_LEFT_Y],
        );

        if (std.math.fabs(axes.x) < dead_zone.x) axes.x = 0;
        if (std.math.fabs(axes.y) < dead_zone.y) axes.y = 0;

        return axes;
    }

    return Vec2.zero;
}

pub fn update(gs: *GameSession, player: *Player, sprite: *Sprite, gun: *Gun) bool {
    const speed: f32 = @floatCast(f32, Time.delta_time * player.speed);

    var delta = Vec2.zero;

    if (Input.getKey(c.KEY_RIGHT) or Input.getKey(c.KEY_D)) delta.x += speed;
    if (Input.getKey(c.KEY_LEFT) or Input.getKey(c.KEY_A)) delta.x -= speed;
    if (Input.getKey(c.KEY_DOWN) or Input.getKey(c.KEY_S)) delta.y += speed;
    if (Input.getKey(c.KEY_UP) or Input.getKey(c.KEY_W)) delta.y -= speed;

    const leftStick = gamepadLeftStick();
    delta.x += speed * leftStick.x;
    delta.y += speed * leftStick.y;

    if (delta.length() > 0.0001) {
        delta = delta.normalize().scale(std.math.min(speed, delta.length()));
    }

    sprite.pos.x += delta.x;
    sprite.pos.y += delta.y;

    gun.fire_right = Input.getKey(c.KEY_L);
    gun.fire_left = Input.getKey(c.KEY_J);
    gun.fire_up = Input.getKey(c.KEY_I);
    gun.fire_down = Input.getKey(c.KEY_K);

    return true;
}
