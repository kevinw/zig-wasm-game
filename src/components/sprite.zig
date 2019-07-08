usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");
usingnamespace @import("../math3d.zig");
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Sprite = struct {
    pos: Vec3 = vec3(0, 0, 0),
    time: f32 = 0,
    index: u16 = 0,
    spritesheet: ?*Spritesheet = null,
    fps: f32 = 12,
};

const SystemData = struct {
    id: EntityId,
    sprite: *Sprite,
};

pub const run = GameSession.buildSystem(SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.sprite.spritesheet) |sheet| {
        self.sprite.time += Time.delta_time;

        const secsPerFrame: f32 = 1.0 / self.sprite.fps;

        while (self.sprite.time > secsPerFrame) {
            self.sprite.time -= secsPerFrame;
            self.sprite.index += 1;
            if (self.sprite.index >= sheet.count) {
                self.sprite.index = 0;
            }
        }
    }

    return true;
}
