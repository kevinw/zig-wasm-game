usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("transform.zig").Transform;

pub const Renderer = struct {
    transform: ?*Transform,

    pub fn getLocalToWorldMatrix(self: *const Renderer) Mat4x4 {
        const mat = if (self.transform) |t| t.world_matrix else Mat4x4.identity;
        return mat;
        //return mat.scale(25, 25, 1); // for size
    }
};

pub fn update(gs: *GameSession, renderer: *Renderer, transform: *Transform) bool {
    return true;
}
