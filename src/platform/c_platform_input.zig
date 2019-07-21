const Vec2 = @import("../math3d.zig").Vec2;
const std = @import("std");

const dead_zone = Vec2.init(0.09, 0.09);

pub fn gamepadLeftStick() Vec2 {
    const c = @import("../platform.zig");

    var state: c.GLFWgamepadstate = undefined;
    if (c.glfwGetGamepadState(0, &state) == 0)
        return Vec2.zero;

    var axes = Vec2.init(
        state.axes[c.GLFW_GAMEPAD_AXIS_LEFT_X],
        state.axes[c.GLFW_GAMEPAD_AXIS_LEFT_Y],
    );

    if (std.math.fabs(axes.x) < dead_zone.x) axes.x = 0;
    if (std.math.fabs(axes.y) < dead_zone.y) axes.y = 0;

    return axes;
}
