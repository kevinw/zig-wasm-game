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
    pub var keys: [255]bool = [_]bool{false} ** 255;
};

pub const log = c.log;
