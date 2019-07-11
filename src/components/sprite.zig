usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");
usingnamespace @import("../math3d.zig");
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Sprite = struct { // !component
    pos: Vec3 = vec3(0, 0, 0),
    time: f32 = 0,
    index: u16 = 0,
    spritesheet: ?*Spritesheet = null,
    fps: f32 = 12,
};

pub fn update(gs: *GameSession, sprite: *Sprite) bool {
    if (sprite.spritesheet) |sheet| {
        sprite.time += Time.delta_time;

        const secsPerFrame: f32 = 1.0 / sprite.fps;

        while (sprite.time > secsPerFrame) {
            sprite.time -= secsPerFrame;
            sprite.index += 1;
            if (sprite.index >= sheet.count) {
                sprite.index = 0;
            }
        }
    }

    return true;
}
