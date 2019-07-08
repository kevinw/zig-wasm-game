usingnamespace @import("../session.zig");
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Sprite = struct {
    current_time: f32,
    spritesheet: ?*Spritesheet,

    pub fn new() Sprite {
        return Sprite{
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
    return true;
}
