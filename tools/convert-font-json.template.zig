const c = @import("platform.zig");
const std = @import("std");

{consts_text}

var did_init = false;

pub const MetricsEntry = struct {{
    values: [7]i16,
}};

const MetricsHashMap = std.AutoHashMap(u32, MetricsEntry);


var _metrics: MetricsHashMap = undefined;

pub fn metrics(allocator: *std.mem.Allocator) *MetricsHashMap {{
    if (!did_init) {{
    _metrics = MetricsHashMap.init(allocator);
{characters}
        did_init = true;
    }}

    return &_metrics;
}}
