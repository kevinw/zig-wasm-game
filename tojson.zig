const std = @import("std");
const Buffer = std.Buffer;
const mem = std.mem;
const assert = std.debug.assert;
const TypeInfo = @import("builtin").TypeInfo;
const TypeId = @import("builtin").TypeId;

fn toJSONacc(buf: *Buffer, value: var) !void {
    switch (@typeInfo(@typeOf(value))) {
        TypeId.Bool => {
            return buf.append(if (value) "true" else "false");
        },
        TypeId.Float => {
            return std.fmt.formatFloatValue(value, "", buf, @typeOf(Buffer.append).ReturnType.ErrorSet, Buffer.append);
        },
        TypeId.Int => {
            return std.fmt.formatIntValue(value, "", buf, @typeOf(Buffer.append).ReturnType.ErrorSet, Buffer.append);
        },
        TypeId.Optional => {
            if (value) |payload| {
                return toJSONacc(buf, payload);
            } else {
                return buf.append("null");
            }
        },
        TypeId.Struct => {
            try buf.append("{");
            comptime var field_i = 0;
            inline while (field_i < @memberCount(@typeOf(value))) : (field_i += 1) {
                if (field_i != 0) {
                    try buf.append(",");
                }
                try toJSONacc(buf, @memberName(@typeOf(value), field_i));
                try buf.append(":");
                try toJSONacc(buf, @field(value, @memberName(@typeOf(value), field_i)));
            }
            try buf.append("}");
            return;
        },
        TypeId.Pointer => |info| switch (info.size) {
            TypeInfo.Pointer.Size.Slice => {
                if (info.child == u8) {
                    try buf.append("\"");
                    var field_i: usize = 0;
                    while (field_i < value.len) : (field_i += 1) {
                        // TODO: escape
                        try buf.appendByte(value[field_i]);
                    }
                    try buf.append("\"");
                    return;
                } else {
                    try buf.append("[");
                    var field_i: usize = 0;
                    while (field_i < value.len) : (field_i += 1) {
                        if (field_i != 0) {
                            try buf.append(",");
                        }
                        try toJSONacc(buf, value[field_i]);
                    }
                    try buf.append("]");
                    return;
                }
            },
            else => @compileError("Unable to toJSON type '" ++ @typeName(@typeOf(value)) ++ "'"),
        },
        TypeId.Array => {
            return toJSONacc(buf, value[0..]);
        },
        else => @compileError("Unable to toJSON type '" ++ @typeName(@typeOf(value)) ++ "'"),
    }
}

pub fn toJSON(value: var) ![]u8 {
    var buf = try Buffer.init(std.debug.global_allocator, "");
    try toJSONacc(&buf, value);
    return buf.toOwnedSlice();
}

test "convert empty struct to JSON" {
    var foo = struct {}(undefined);
    assert(mem.eql(u8, try toJSON(foo), "{}"));
}

test "convert comptime string to JSON" {
    comptime var foo = "foobar";
    assert(mem.eql(u8, try toJSON(foo),
        \\"foobar"
    ));
}

test "convert simple struct to JSON" {
    var foo = struct {
            x: u32,
            str: [6]u8,
        }{
        .x = 42,
        .str = "string",
    };
    assert(mem.eql(u8, try toJSON(foo),
        \\{"x":42,"str":"string"}
    ));
}
