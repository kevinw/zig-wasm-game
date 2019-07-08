usingnamespace @import("math3d.zig");
const gbe = @import("gbe");
const c = @import("components.zig");
const GameSession = @import("session.zig").GameSession;

pub const Player = struct {
    pub const Params = struct {};

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);
        try gs.addComponent(entity_id, c.Player{ .pos = vec3(0, 0, 0) });
        try gs.addComponent(entity_id, c.Sprite.new());
        return entity_id;
    }
};
