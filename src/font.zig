const Spritesheet = @import("spritesheet.zig").Spritesheet;

pub const Font = struct {
    spritesheet: *Spritesheet,

    pub fn drawText(text: []u8) void {}
};
