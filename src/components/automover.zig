usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const AutoMover = struct {
    rotate_angle: f32 = 10,
    rotate_axis: Vec3 = vec3(1, 0, 0),
};

pub fn update(gs: *GameSession, auto_mover: *AutoMover, transform: *Transform) bool {
    transform.local_matrix = transform.local_matrix.rotate(auto_mover.rotate_angle, auto_mover.rotate_axis);
    return true;
}
