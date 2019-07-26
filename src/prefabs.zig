usingnamespace @import("math3d.zig");
const gbe = @import("gbe");
const c = @import("components_auto.zig");
const GameSession = @import("session.zig").GameSession;

fn spawn_entity(gs: *GameSession, translation: Vec3, scale: Vec3, parent: ?*c.Transform) !*gbe.ComponentObject(c.Transform) {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    const xform = c.Transform{
        .position = translation,
        .scale = scale,
    };

    const transform = try gs.addComponent(entity_id, xform);
    //if (parent) |p| {} else {
    //_ = try gs.addComponent(entity_id, c.AutoMover{});
    //}

    _ = try gs.addComponent(entity_id, c.Renderer{ .transform = &transform.data });

    if (parent) |p| {
        transform.data.setParent(p);
    }

    return transform;
}

pub fn spawn_solar_system(gs: *GameSession) !gbe.EntityId {
    const sun = try spawn_entity(gs, vec3(0, 0, 0), vec3(30, 30, 1), null);
    const earth = try spawn_entity(gs, vec3(80, 0, 0), vec3(0.2, 0.2, 1), &sun.data);
    const moon = try spawn_entity(gs, vec3(10, 0, 0), vec3(0.5, 0.5, 1), &earth.data);
    return sun.entity_id;
}

pub const Player = struct {
    pub const Params = struct {};

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        _ = try gs.addComponent(entity_id, c.Player{});
        _ = try gs.addComponent(entity_id, c.Sprite{});
        _ = try gs.addComponent(entity_id, c.Gun{ .offset = vec3(24, 24, 0) });

        return entity_id;
    }
};

pub const Bullet = struct {
    pub fn spawn(gs: *GameSession, pos: Vec3, vel: Vec3) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);
        const game_state = &@import("game.zig").game_state;

        _ = try gs.addComponent(entity_id, c.Sprite{ .pos = pos, .spritesheet = &game_state.bullet_sprite });
        _ = try gs.addComponent(entity_id, c.Mover{ .vel = vel });
        _ = try gs.addComponent(entity_id, c.Destroy_Timer{ .secs_left = 1.5 });

        return entity_id;
    }
};

pub const Mojulo = struct {
    pub fn spawn(gs: *GameSession, pos: Vec3) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        _ = try gs.addComponent(entity_id, c.Mojulo{});
        _ = try gs.addComponent(entity_id, c.Transform{ .position = pos });

        return entity_id;
    }
};
