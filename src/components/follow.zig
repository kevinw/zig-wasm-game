//capacity=10

usingnamespace @import("../globals.zig");
const Sprite = @import("./sprite.zig").Sprite;
const GameSession = @import("../session.zig").GameSession;
const game_math = @import("../game_math.zig");

pub const Follow = struct {
    offset: Vec3 = Vec3.zero,
    target: ?*Sprite,

    current_pos: Vec3 = Vec3.zero,
    current_vel: Vec3 = Vec3.zero,
    smooth_time: f32 = 0.2,

    view_matrix: Mat4x4 = Mat4x4.identity,

    pub fn spawn(gs: *GameSession, target: *Sprite) !*Follow {
        const id = gs.spawn();
        errdefer gs.undoSpawn(id);
        const followCObj = try gs.addComponent(id, Follow{ .target = target });
        return &followCObj.data;
    }

    pub fn getViewMatrix(self: *Follow) Mat4x4 {
        return self.view_matrix;
    }
};

pub fn update(gs: *GameSession, follow: *Follow) bool {
    if (follow.target) |sprite| {
        const target_pos = sprite.pos.multScalar(-1).add(follow.offset);
        follow.current_pos = game_math.smooth_damp_vec3(follow.current_pos, target_pos, &follow.current_vel, follow.smooth_time, Time.delta_time);
        follow.view_matrix = mat4x4_identity.translateVec(follow.current_pos);
    }

    return true;
}
