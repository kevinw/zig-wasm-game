usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;

pub const Destroy_Timer = struct {
    secs_left: f32,
};

pub fn update(gs: *GameSession, timer: *Destroy_Timer) bool {
    const was_positive = timer.secs_left > 0;
    timer.secs_left -= Time.delta_time;
    if (was_positive and timer.secs_left < 0) {
        return false;
    }

    return true;
}
