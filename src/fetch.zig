const std = @import("std");
const RawImage = @import("png.zig").RawImage;
const c = @import("platform.zig");
const Spritesheet = @import("spritesheet.zig").Spritesheet;
usingnamespace @import("globals.zig");

pub const SpritesheetFromCellSizeArgs = struct {
    spritesheet: *Spritesheet,
    cell_width: u16,
    cell_height: u16,
};

pub const FetchType = union(enum) {
    SpritesheetFromCellSize: SpritesheetFromCellSizeArgs,
};

var nextToken: u32 = 1;

pub fn fromCellSize(path: []const u8, s: *Spritesheet, w: u16, h: u16) !void {
    const fetch_type = FetchType{
        .SpritesheetFromCellSize = SpritesheetFromCellSizeArgs{
            .cell_width = w,
            .cell_height = h,
            .spritesheet = s,
        },
    };

    try get(path, fetch_type);
}

const PendingFetch = struct {
    token: u32,
    fetch_type: FetchType,
};

var pending: std.ArrayList(PendingFetch) = undefined;
var did_init = false;

pub fn get(path: []const u8, fetch_type: FetchType) !void {
    if (!did_init) {
        pending = std.ArrayList(PendingFetch).init(c.allocator);
        did_init = true;
    }

    try pending.append(PendingFetch{
        .token = nextToken,
        .fetch_type = fetch_type,
    });

    c.fetchBytes(path.ptr, path.len, nextToken);
    nextToken += 1;
}

pub fn didFetch(token: u32, raw_image: RawImage) void {
    for (pending.toSlice()) |f, i| {
        if (f.token != token) continue;

        const entry = pending.orderedRemove(i);

        switch (entry.fetch_type) {
            .SpritesheetFromCellSize => |args| {
                args.spritesheet.init(raw_image, args.cell_width, args.cell_height) catch |err| {
                    c.log("error initing spritesheet for token {}: {}", token, err);
                };
            },
        }

        break;
    } else {
        @panic("unknown token in didFetch");
    }
}
