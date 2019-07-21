const builtin = @import("builtin");
const c = @import("platform.zig");
pub usingnamespace @import("math3d.zig");

pub const Time = struct {
    pub var time: f32 = 0;
    pub var delta_time: f32 = 0;
    pub var frame_count: f32 = 0;

    pub fn _update_next_frame(elapsed: f64) void {
        Time.delta_time = @floatCast(f32, elapsed);
        Time.time += Time.delta_time;
        Time.frame_count += 1;
    }
};

pub const Input = struct {
    const Self = @This();

    pub fn getKey(keyCode: KeyCode) bool {
        return c.platformGetKey(keyCode);
    }
};

pub const KeyCode = c.KeyCode;

pub const log = @import("log.zig").log;
