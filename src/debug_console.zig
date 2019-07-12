usingnamespace @import("math3d.zig");
const CappedArrayList = @import("capped_array_list.zig").CappedArrayList;
const Spritesheet = @import("spritesheet.zig").Spritesheet;
const game = @import("game.zig");
const game_math = @import("game_math.zig");
const c = @import("platform.zig");
const assert = @import("std").debug.assert;

const MAX_ENTRIES = 10;

pub const ConsoleEntry = struct {
    message: []const u8,
    time: f64,
};

pub const DebugConsole = struct {
    const Self = @This();
    const font_size: u32 = 1;
    const time_visible = 2.0;

    entries: CappedArrayList(ConsoleEntry, MAX_ENTRIES),
    now: f64,

    pub fn init() DebugConsole {
        var console: DebugConsole = undefined;
        console.reset();
        return console;
    }

    pub fn reset(self: *Self) void {
        self.now = 0;
        self.entries.len = 0;
    }

    pub fn destroy(self: *Self) void {}

    pub fn log(self: *Self, message: []const u8) void {
        while (self.entries.len == MAX_ENTRIES) {
            _ = self.entries.orderedRemove(0);
        }

        self.entries.append(ConsoleEntry{
            .time = self.now,
            .message = message,
        }) catch {
            c.log("error: log full!");
        };
    }

    pub fn update(self: *Self, dt: f64) void {
        self.now += dt;

        var new_entries = CappedArrayList(ConsoleEntry, MAX_ENTRIES).init();

        for (self.entries.toSliceConst()) |*entry| {
            const elapsed = self.now - entry.time;
            if (elapsed < time_visible) {
                new_entries.append(entry.*) catch {
                    c.log("error: log was bigger than we expected");
                };
            }
        }

        self.entries = new_entries;
    }

    pub fn draw(self: *Self, t: *const game.Game) void {
        if (self.entries.len == 0) return;

        var x: i32 = 10;
        var y: i32 = 10;
        var color = vec4(1, 1, 1, 1);

        for (self.entries.toSliceConst()) |*entry| {
            const elapsed = self.now - entry.time;
            const alpha = alphaForTime(@floatCast(f32, elapsed));
            color.w = alpha;
            game.drawTextWithColor(t, entry.message, x, y, font_size, color);
            y += game.font_char_height;
        }
    }

    fn alphaForTime(elapsed: f32) f32 {
        return 1.0 - game_math.saturate(game_math.unlerp(elapsed, time_visible - 0.5, time_visible));
    }
};

test "overflowing the buffer" {
    var d = DebugConsole.init();
    d.log("foo");
    d.log("bar");
    d.log("meep");
}
