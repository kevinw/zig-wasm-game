usingnamespace @import("math3d.zig");
const std = @import("std");
const gbe = @import("gbe");
const c = @import("components_auto.zig");
const GameSession = @import("session.zig").GameSession;

fn spawn_entity(gs: *GameSession, translation: Vec3, scale: Vec3, parent: ?*c.Transform, needs_renderer: bool, rotate_speed: f32) !*gbe.ComponentObject(c.Transform) {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    const xform = c.Transform{
        .position = translation,
        .scale = scale,
    };

    const transform = try gs.addComponent(entity_id, xform);
    if (std.math.fabs(rotate_speed) > 0)
        _ = try gs.addComponent(entity_id, c.AutoMover{ .rotate_angle = rotate_speed });

    if (needs_renderer)
        _ = try gs.addComponent(entity_id, c.Renderer{ .transform = &transform.data });

    if (parent) |p|
        transform.data.setParent(p);

    return transform;
}

pub fn spawn_solar_system(gs: *GameSession) !gbe.EntityId {
    const sun_size = vec3(40, 40, 1);
    const earth_size = vec3(20, 20, 1);
    const moon_size = vec3(15, 15, 1);

    const solar_system = try spawn_entity(gs, vec3(0, 0, 0), vec3(1, 1, 1), null, false, 2);
    const sun = try spawn_entity(gs, vec3(0, 0, 0), sun_size, &solar_system.data, true, -1.5);

    const earth_orbit = try spawn_entity(gs, vec3(150, 0, 0), vec3(1, 1, 1), &solar_system.data, false, 1);
    const earth = try spawn_entity(gs, vec3(0, 0, 0), earth_size, &earth_orbit.data, true, 0);

    const moon_orbit = try spawn_entity(gs, vec3(45, 0, 0), vec3(1, 1, 1), &earth_orbit.data, false, 3);
    const moon = try spawn_entity(gs, vec3(0, 0, 0), moon_size, &moon_orbit.data, true, 0);

    return solar_system.entity_id;
}

pub fn spawn_entity_with_components(gs: *GameSession, args: ...) !gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    comptime var i: usize = 0;
    inline while (i < args.len) : (i += 1)
        _ = try gs.addComponent(entity_id, args[i]);

    return entity_id;
}

pub const Player = struct {
    pub const Params = struct {};

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        _ = try gs.addComponent(entity_id, c.Player{});
        const xform = try gs.addComponent(entity_id, c.Transform{ .scale = vec3(4, 4, 1) });
        _ = try gs.addComponent(entity_id, c.Renderer{ .transform = &xform.data });
        _ = try gs.addComponent(entity_id, c.Sprite{});
        _ = try gs.addComponent(entity_id, c.Gun{ .offset = vec3(24, 24, 0) });

        return entity_id;
    }
};

pub const Bullet = struct {
    pub fn spawn(gs: *GameSession, pos: Vec3, vel: Vec3) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);
        const game_state = &@import("game.zig").game_state; // TODO: no

        _ = try gs.addComponent(entity_id, c.Sprite{ .pos = pos, .spritesheet = &game_state.bullet_sprite });
        const xform = try gs.addComponent(entity_id, c.Transform{ .position = pos, .scale = vec3(4, 4, 1) });
        _ = try gs.addComponent(entity_id, c.Renderer{ .transform = &xform.data });
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
