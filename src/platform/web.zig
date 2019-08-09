const std = @import("std");
const wasm = @import("web/wasm.zig");
const webgl = @import("web/webgl.zig");

pub usingnamespace @import("web/wasm.zig");
pub usingnamespace @import("web/webgl.zig");

const builtin = @import("builtin");
pub const allocator = @import("std").heap.wasm_allocator;
pub const Window = c_void;

pub var wasm_keys: [256]bool = [_]bool{false} ** 256;

pub const KeyCode = usize;

pub fn platformGetKey(keyCode: KeyCode) bool {
    return wasm_keys[keyCode];
}

//pub fn allocPrint(allocator: *mem.Allocator, comptime fmt: []const u8, args: ...) AllocPrintError![]u8 {

pub fn log(comptime fmt: []const u8, args: ...) void {
    const s = std.fmt.allocPrint(allocator, fmt, args) catch unreachable;
    wasm.consoleLogS(s.ptr, s.len);
}

pub const warn = log;

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    wasm.consoleLogS(message.ptr, message.len);
    //wasm.debugBreak();
    //while (true) {}
}

pub fn initShader(source: []const u8, name: []const u8, kind: c_uint) c_uint {
    return webgl.glInitShader(source.ptr, source.len, kind);
}

pub fn linkShaderProgram(vertex_id: c_uint, fragment_id: c_uint, geometry_id: ?c_uint) c_uint {
    return webgl.glLinkShaderProgram(vertex_id, fragment_id);
}

pub fn fetchBytesSlice(url: []const u8, token: u32) void {
    wasm.fetchBytes(url.ptr, url.len, token);
}

pub fn glGetProgramiv(program_id: c_uint, info_type: c_int, value: *c_int) void {
    const result = webgl.glGetProgramParameter(program_id, info_type);
    if (result != 0)
        value.* = result;
}
