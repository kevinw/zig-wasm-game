usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const AutoMover = struct {
    rotate_angle: f32 = 3,
    rotate_axis: Vec3 = vec3(0, 0, 1),
};

pub fn update(gs: *GameSession, auto_mover: *AutoMover, transform: *Transform) bool {
    const angle = auto_mover.rotate_angle * Time.delta_time;
    transform.local_matrix = transform.local_matrix.rotate(angle, auto_mover.rotate_axis);
    return true;
}
