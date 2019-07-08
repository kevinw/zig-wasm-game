usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");
usingnamespace @import("../math3d.zig");
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Sprite = struct {
    current_time: f32,
    spritesheet: ?*Spritesheet,
    pos: Vec3,

    pub fn new() @This() {
        return @This(){
            .pos = vec3(0, 0, 0),
            .current_time = 0,
            .spritesheet = null,
        };
    }
};

const SystemData = struct {
    id: EntityId,
    sprite: *Sprite,
};

pub const run = GameSession.buildSystem(SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    self.sprite.current_time += Time.delta_time;

    return true;
}
