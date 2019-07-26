usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const AutoMover = struct {
    rotate_angle: f32 = 2,
    rotate_axis: Vec3 = vec3(0, 0, 1),
};

pub fn update(gs: *GameSession, auto_mover: *AutoMover, transform: *Transform) bool {
    const angle = auto_mover.rotate_angle * Time.delta_time;

    transform.rotation = transform.rotation.add(auto_mover.rotate_axis.scale(angle));

    return true;
}
