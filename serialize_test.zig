const warn = @import("std").debug.warn;
const io = @import("std").io;

const tojson = @import("tojson.zig");

const foo = struct {
    bar: i32,
};

pub fn main() void {
    warn("hello world\n");

    const f = foo{ .bar = 24 };

    warn("{}\n", tojson.toJSON(f) catch "error");
}
