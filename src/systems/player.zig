usingnamespace @import("../components.zig");
usingnamespace @import("../session.zig");
usingnamespace @import("../globals.zig");

const SystemData = struct {
    id: EntityId,
    player: *Player,
    sprite: *Sprite,
};

pub const run = GameSession.buildSystem(SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    const speed: f32 = @floatCast(f32, Time.delta_time * self.player.speed);
    const pos = &self.sprite.pos.data;

    const c = @import("../platform.zig");
    const keys = &Input.keys;
    if (keys[c.KEY_RIGHT] or keys[c.KEY_D]) pos[0] += speed;
    if (keys[c.KEY_LEFT] or keys[c.KEY_A]) pos[0] -= speed;
    if (keys[c.KEY_DOWN] or keys[c.KEY_S]) pos[1] += speed;
    if (keys[c.KEY_UP] or keys[c.KEY_W]) pos[1] -= speed;

    return true;
}
