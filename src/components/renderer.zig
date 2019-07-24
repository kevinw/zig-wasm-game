usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const Renderer = struct {
    transform: ?*Transform,

    pub fn getLocalToWorldMatrix(self: *const Renderer) Mat4x4 {
        if (self.transform) |t| {
            return t.world_matrix;
        }

        return Mat4x4.identity;
    }
};

pub fn update(gs: *GameSession, renderer: *Renderer, transform: *Transform) bool {
    return true;
}
