/// Translates a compiled tinyexpr Expr into valid GLSL code.
const std = @import("std");
const builtin = @import("builtin");
pub const warn = @import("base.zig").warn;
const tinyexpr = @import("tinyexpr.zig");
const Expr = tinyexpr.Expr;
const Variable = tinyexpr.Variable;
const FuncCall = tinyexpr.FuncCall;

var test_memory: [32 * 1024]u8 = undefined;
var test_fba_state = std.heap.FixedBufferAllocator.init(&test_memory);
const test_allocator = &test_fba_state.allocator;

/// Variables with these addresses will be passed through to the output by
/// name.
const passThroughVars = struct {
    var x: f64 = 0;
    var y: f64 = 0;
    var time: f64 = 0;
    var A: f64 = 0;
    var r: f64 = 0;
};

fn isPassThroughVar(address: *f64) bool {
    // Returns true if address points to a declared variable
    // in the special "passThroughVars" struct above.
    switch (@typeInfo(passThroughVars)) {
        builtin.TypeId.Struct => |structInfo| {
            inline for (structInfo.decls) |decl| {
                if (address == &@field(passThroughVars, decl.name))
                    return true;
            }
        },
        else => unreachable,
    }
    return false;
}

const passThroughFuncs = [_][]const u8{
    "pow",
    "sin",
    "cos",
    "tan",
    "rand",
    "abs",
};

fn getGLSLFuncNameForBuiltinName(name: []const u8) ![]const u8 {
    inline for (passThroughFuncs) |funcName|
        if (std.mem.eql(u8, funcName, name)) return name;

    warn("invalid GLSL func: {}\n", name);
    return error.InvalidGLSLFunc;
}

fn getGLSLFuncName(f: tinyexpr.Function) ![]const u8 {
    for (tinyexpr.builtinFunctions) |builtinFunc| {
        if (builtinFunc.eq(f.fptr)) {
            return try getGLSLFuncNameForBuiltinName(builtinFunc.name);
        }
    }

    warn("invalid GLSL func: {}\n", f);
    return error.InvalidGLSLFunc;
}

fn printValueToBuffer(buf: *std.Buffer, value: f64) !void {
    const format = "{d}";
    const value_str = try std.fmt.allocPrint(test_allocator, format, value);
    defer test_allocator.free(value_str);
    try buf.append(value_str);

    // here we're adding a .0 to stringified f64s that are round numbers,
    // so that glsl won't automatically assume they are ints.
    // TODO: how to add a .0 with a format specifier?
    if (std.mem.indexOfScalar(u8, value_str, '.')) |i| {} else {
        try buf.append(".0");
    }
}

const TinyGLSLError = error{
    InvalidGLSLFunc,
    OutOfMemory,
};

fn needsParens(f: *Expr) bool {
    return switch (f.*) {
        .Function => true,
        .Variable, .Constant => false,
    };
}

fn infix(buf: *std.Buffer, f: tinyexpr.Function, op_str: []const u8) !void {
    if (needsParens(f.params[0])) {
        try buf.append("(");
    }
    try toGLSL(f.params[0], buf);
    if (needsParens(f.params[0])) {
        try buf.append(") ");
    } else {
        try buf.append(" ");
    }

    try buf.append(op_str);

    if (needsParens(f.params[1])) {
        try buf.append(" (");
    } else {
        try buf.append(" ");
    }
    try toGLSL(f.params[1], buf);
    if (needsParens(f.params[1])) {
        try buf.append(")");
    }
}

fn isBuiltin(f: tinyexpr.Function, name: []const u8) bool {
    if (tinyexpr.findBuiltin(name)) |builtinFunc|
        return builtinFunc.eq(f.fptr);

    warn("isBuiltin(\"{}\") - not a valid builtin", name);
    unreachable;
}

fn toGLSL(n: *const Expr, buf: *std.Buffer) TinyGLSLError!void {
    switch (n.*) {
        .Constant => |value| {
            try printValueToBuffer(buf, value);
        },
        .Variable => |bound| {
            if (isPassThroughVar(bound.address)) {
                try buf.append(bound.name);
            } else {
                try printValueToBuffer(buf, bound.address.*);
            }
        },
        .Function => |f| {
            if (isBuiltin(f, "add")) {
                try infix(buf, f, "+");
            } else if (isBuiltin(f, "sub")) {
                try infix(buf, f, "-");
            } else if (isBuiltin(f, "mul")) {
                try infix(buf, f, "*");
            } else if (isBuiltin(f, "divide")) {
                try infix(buf, f, "/");
            } else if (isBuiltin(f, "negate")) {
                try buf.append("-");
                try toGLSL(f.params[0], buf);
            } else {
                try buf.append(try getGLSLFuncName(f));
                try buf.append("(");
                for (f.params) |p, i| {
                    try toGLSL(p, buf);
                    if (i != f.params.len - 1)
                        try buf.append(", ");
                }
                try buf.append(")");
            }
        },
    }
}

pub fn translate(buf: *std.Buffer, tiny: []const u8) !void {
    const expr = try tinyexpr.compile(buf.list.allocator, tiny, test_vars);
    try toGLSL(expr, buf);
}

fn assertGLSL(tinyexpr_str: []const u8, expected_glsl: []const u8) !void {
    var buf = try std.Buffer.init(test_allocator, "");
    defer buf.deinit();

    try translate(&buf, tinyexpr_str);

    const actual = buf.toSliceConst();
    //warn("\n\nactual  : {}\nexpected: {}\n", actual, expected_glsl);
    std.testing.expectEqualSlices(u8, expected_glsl, buf.toSliceConst());
}

var test_vars = blk: {
    const decls = @typeInfo(passThroughVars).Struct.decls;
    var v: [decls.len]Variable = undefined;
    inline for (decls) |decl, i|
        v[i] = Variable.init(decl.name, &@field(passThroughVars, decl.name));
    break :blk v;
};

test "ints to floats" {
    try assertGLSL("2", "2.0");
    try assertGLSL("-42", "-42.0");
}

test "infix to function" {
    try assertGLSL("2^3", "pow(2.0, 3.0)");
    try assertGLSL("x^y", "pow(x, y)");
}

test "infix parens" {
    try assertGLSL("1+2", "1.0 + 2.0");
    try assertGLSL("1+2*3", "1.0 + (2.0 * 3.0)");
}

test "pass through vars" {
    try assertGLSL("time", "time");
    try assertGLSL("x*y*time", "(x * y) * time");
}
