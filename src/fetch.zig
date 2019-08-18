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

pub const FetchCallback = fn(raw_image: RawImage) void;

pub const WithCallbackArgs = struct {
    cb: FetchCallback,
};

pub const FetchType = union(enum) {
    SpritesheetFromCellSize: SpritesheetFromCellSizeArgs,
    WithCallback: WithCallbackArgs,
};

var nextToken: u32 = 1;

pub fn withCallback(path: []const u8, cb: FetchCallback, w: u16, h: u16) !void {
    const fetch_type = FetchType{
        .WithCallback = WithCallbackArgs {
            .cb=cb
        }
    };

    try get(path, fetch_type);
}

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

    c.fetchBytesSlice(path, nextToken);
    nextToken += 1;
}

fn reverseImageY(bytes: []u8, pitch: u32) ![]u8 {
    const new_bytes = try c.allocator.alloc(u8, bytes.len);
    const num_rows = bytes.len / pitch;

    var i: u32 = 0;
    while (i < num_rows) : (i += 1) {
        const row_start = i * pitch;
        const new_row_start = (num_rows - i - 1) * pitch;

        const dest = new_bytes[new_row_start .. new_row_start + pitch];
        const src = bytes[row_start .. row_start + pitch];

        std.mem.copy(u8, dest, src);
    }

    //pub fn copy(comptime T: type, dest: []T, source: []const T) void {
    return new_bytes;
}

pub fn onFetch(width: u32, height: u32, bytes: []u8, token: c_uint) void {
    const pitch = @intCast(u32, bytes.len / height);

    var flippedSlice = if (c.NEEDS_Y_FLIP)
        reverseImageY(bytes, pitch) catch unreachable
    else
        bytes;

    didFetch(token, RawImage{
        .width = width,
        .height = height,
        .pitch = pitch,
        .raw = flippedSlice,
    });

    if (c.NEEDS_Y_FLIP)
        c.allocator.free(flippedSlice);
}

pub fn didFetch(token: u32, raw_image: RawImage) void {
    for (pending.toSlice()) |f, i| {
        if (f.token != token) continue;

        const entry = pending.orderedRemove(i);

        switch (entry.fetch_type) {
            .SpritesheetFromCellSize => |args| {
                args.spritesheet.init(raw_image, args.cell_width, args.cell_height) catch |err| {
                    log("error initing spritesheet for token {}: {}", token, err);
                };
            },

            .WithCallback => |args| {
                args.cb(raw_image);
            }
        }

        break;
    } else {
        @panic("unknown token in didFetch");
    }
}
