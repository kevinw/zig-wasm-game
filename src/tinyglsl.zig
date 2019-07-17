const std = @import("std");

const builtin = @import("builtin");

const tinyexpr = @import("tinyexpr.zig");
const Expr = tinyexpr.Expr;
const Variable = tinyexpr.Variable;
const FuncCall = tinyexpr.FuncCall;

var test_memory: [32 * 1024]u8 = undefined;
var test_fba_state = std.heap.FixedBufferAllocator.init(&test_memory);
const test_allocator = &test_fba_state.allocator;

const passThroughVars = struct {
    // Variables with these addresses will be passed through to the output by
    // name.
    var x: f64 = 0;
    var y: f64 = 0;
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

fn getGLSLFuncNameForBuiltinName(name: []const u8) ![]const u8 {
    comptime const eql = std.mem.eql;
    if (eql(u8, "pow", name)) return "pow";

    std.debug.warn("invalid GLSL func: {}\n", name);
    return error.InvalidGLSLFunc;
}

fn getGLSLFuncName(f: tinyexpr.Function) ![]const u8 {
    for (tinyexpr.builtinFunctions) |builtinFunc| {
        if (builtinFunc.eq(f.fptr)) {
            return try getGLSLFuncNameForBuiltinName(builtinFunc.name);
        }
    }

    std.debug.warn("invalid GLSL func: {}\n", f);
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

fn infix(buf: *std.Buffer, f: tinyexpr.Function, op_str: []const u8) !void {
    try buf.append("(");
    try toGLSL(f.params[0], buf);
    try buf.append(") ");

    try buf.append(op_str);

    try buf.append(" (");
    try toGLSL(f.params[1], buf);
    try buf.append(")");
}

fn isBuiltin(f: tinyexpr.Function, name: []const u8) bool {
    if (tinyexpr.findBuiltin(name)) |builtinFunc| {
        return builtinFunc.eq(f.fptr);
    }
    return false;
}

fn toGLSL(n: *const Expr, buf: *std.Buffer) TinyGLSLError!void {
    switch (n.*) {
        .Function => |f| {
            if (isBuiltin(f, "add")) {
                try infix(buf, f, "+");
            } else if (isBuiltin(f, "sub")) {
                try infix(buf, f, "-");
            } else if (isBuiltin(f, "mul")) {
                try infix(buf, f, "*");
            } else if (isBuiltin(f, "div")) {
                try infix(buf, f, "/");
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
        .Variable => |bound| {
            if (isPassThroughVar(bound.address)) {
                try buf.append(bound.name);
            } else {
                try printValueToBuffer(buf, bound.address.*);
            }
        },
        .Constant => |value| {
            try printValueToBuffer(buf, value);
        },
    }
}

fn assertGLSL(tinyexpr_str: []const u8, expected_glsl: []const u8, vars: []Variable) !void {
    var buf = try std.Buffer.init(test_allocator, "");
    const expr = try tinyexpr.compile(test_allocator, tinyexpr_str, vars);
    try toGLSL(expr, &buf);

    const actual = buf.toSliceConst();
    //std.debug.warn("\n\nactual  : {}\nexpected: {}\n", actual, expected_glsl);
    std.testing.expectEqualSlices(u8, expected_glsl, buf.toSliceConst());
}

test "translate" {
    var vars = [_]Variable{ Variable.init("x", &passThroughVars.x), Variable.init("y", &passThroughVars.y) };
    try assertGLSL("2^3", "pow(2.0, 3.0)", vars[0..]);
    try assertGLSL("1+2", "(1.0) + (2.0)", vars[0..]);
    try assertGLSL("1+2*3", "(1.0) + ((2.0) * (3.0))", vars[0..]);
    try assertGLSL("x^y", "pow(x, y)", vars[0..]);
}
