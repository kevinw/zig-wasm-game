usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Sprite = struct {
    current_time: f32,
    spritesheet: ?*Spritesheet,

    pub fn new() @This() {
        return @This(){
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
