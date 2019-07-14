usingnamespace @import("math3d.zig");
const gbe = @import("gbe");
const c = @import("components_auto.zig");
const GameSession = @import("session.zig").GameSession;

pub const Player = struct {
    pub const Params = struct {};

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Player{});
        try gs.addComponent(entity_id, c.Sprite{});
        try gs.addComponent(entity_id, c.Gun{ .offset = vec3(24, 24, 0) });

        return entity_id;
    }
};

pub const Bullet = struct {
    pub fn spawn(gs: *GameSession, pos: Vec3, vel: Vec3) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);
        const game_state = &@import("game.zig").game_state;

        try gs.addComponent(entity_id, c.Sprite{ .pos = pos, .spritesheet = &game_state.bullet_sprite });
        try gs.addComponent(entity_id, c.Mover{ .vel = vel });
        try gs.addComponent(entity_id, c.Destroy_Timer{ .secs_left = 0.5 });

        return entity_id;
    }
};

pub const Mojulo = struct {
    pub fn spawn(gs: *GameSession, pos: Vec3) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Sprite{ .pos = pos });

        return entity_id;
    }
};
