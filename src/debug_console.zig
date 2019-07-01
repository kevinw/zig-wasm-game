usingnamespace @import("math3d.zig");
const CappedArrayList = @import("capped_array_list.zig").CappedArrayList;
const Spritesheet = @import("spritesheet.zig").Spritesheet;
const game = @import("game.zig");

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

    pub fn init(self: *Self) void {
        self.now = 0;
        self.entries.len = 0;
    }

    pub fn destroy(self: *Self) void {}

    pub fn log(self: *Self, message: []const u8) void {
        self.entries.append(ConsoleEntry{
            .time = self.now,
            .message = message,
        }) catch unreachable;
    }

    pub fn update(self: *Self, dt: f64) void {
        self.now += dt;

        var new_entries = CappedArrayList(ConsoleEntry, MAX_ENTRIES).init();

        for (self.entries.toSliceConst()) |*entry| {
            const elapsed = self.now - entry.time;
            if (elapsed < time_visible) {
                new_entries.append(entry.*) catch unreachable;
            }
        }

        self.entries = new_entries;
    }

    pub fn draw(self: *Self, t: *const game.Tetris) void {
        if (self.entries.len == 0) return;

        var x: i32 = 10;
        var y: i32 = 10;

        for (self.entries.toSliceConst()) |*entry| {
            const elapsed = self.now - entry.time;
            const alpha = alphaForTime(elapsed);
            //color.a = alpha;
            //font.draw_text(entry.message, x, y, font_size, color);
            game.drawText(t, entry.message, x, y, font_size);
            y += game.font_char_height;
        }
    }

    fn alphaForTime(elapsed: f64) u8 {
        return 255;
    }
};
