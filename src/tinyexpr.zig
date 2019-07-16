const std = @import("std");
const warn = std.debug.warn;
const VERBOSE = false;

fn _FuncPtr(comptime arity: u8) type {
    return switch (arity) {
        0 => fn () f64,
        1 => fn (a: f64) f64,
        2 => fn (a: f64, b: f64) f64,
        3 => fn (a: f64, b: f64, c: f64) f64,
        else => unreachable,
    };
}

fn _Func(comptime arity: u8) type {
    return struct {
        parameters: if (arity > 0) [arity]*Expr else void,
        function: _FuncPtr(arity),
    };
}

const Func0 = _Func(0);
const Func1 = _Func(1);
const Func2 = _Func(2);

const EvalError = error{NotImplemented};

const Func = union(enum) {
    const Self = @This();

    Func0: Func0,
    Func1: Func1,
    Func2: Func2,

    fn eval_fn(self: Self, allocator: *std.mem.Allocator) EvalError!f64 {
        return switch (self) {
            .Func0 => |f| f.function(),
            .Func1 => |f| f.function(try eval(allocator, f.parameters[0])),
            .Func2 => |f| f.function(try eval(allocator, f.parameters[0]), try eval(allocator, f.parameters[1])),
            else => return EvalError.NotImplemented,
        };
    }
};

const FuncPtr = union(enum) {
    Func0: _FuncPtr(0),
    Func1: _FuncPtr(1),
    Func2: _FuncPtr(2),

    fn is(self: ?FuncPtr, comptime arity: u8, func: var) bool {
        if (self) |f| {
            return switch (f) {
                .Func0 => |theFunction| if (@typeOf(func) == @typeOf(theFunction)) func == theFunction else false,
                .Func1 => |theFunction| if (@typeOf(func) == @typeOf(theFunction)) func == theFunction else false,
                .Func2 => |theFunction| if (@typeOf(func) == @typeOf(theFunction)) func == theFunction else false,
                else => false,
            };
        }
        return false;
    }
};

const Expr = union(enum) {
    Variable: *f64,
    Constant: f64,
    Function: Func,
};

const Variable = struct {
    name: []const u8,
    address: *f64,
    type: Expr,
    context: *f64,
};

const TokenType = enum {
    Null,
    End,
    Number,
    Infix,
    Open,
    Close,
    Sep,
    Error,
};

inline fn isDigit(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '.';
}

inline fn isLetter(ch: u8) bool {
    return ch >= 'a' and ch <= 'z';
}

fn fmod(a: f64, b: f64) f64 {
    std.debug.panic("todo: implement fmod");
}

fn pow(base_n: f64, exponent: f64) f64 {
    std.debug.panic("todo: implement pow");
}

fn negate(a: f64) f64 {
    return -a;
}

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn sub(a: f64, b: f64) f64 {
    return a - b;
}

fn mul(a: f64, b: f64) f64 {
    return a * b;
}

fn divide(a: f64, b: f64) f64 {
    return a / b;
}

fn comma(a: f64, b: f64) f64 {
    return b;
}

const State = struct {
    allocator: *std.mem.Allocator,

    start: []const u8,
    next: []const u8,
    lookup: ?[]Variable,
    tokenType: TokenType = .Null,

    value: f64 = 0,
    function: ?FuncPtr = null,

    fn nextToken(s: *State) !void {
        s.tokenType = .Null;
        var debugCount: u16 = 0;
        while (true) {
            if (VERBOSE) std.debug.warn("----\n{} nextToken loop, next is: '{}'\n", debugCount, s.next);
            debugCount += 1;

            if (s.next.len == 0) {
                if (VERBOSE) std.debug.warn("none left, setting end\n");
                s.tokenType = .End;
                return;
            }

            // Try reading a number.
            if (isDigit(s.next[0])) {
                var i: usize = 0;
                while (i < s.next.len and isDigit(s.next[i])) : (i += 1) {}
                s.value = try std.fmt.parseFloat(f64, s.next[0..i]);
                if (VERBOSE) warn("parsed float from '{}': {}\n", s.next[0..i], s.value);
                s.tokenType = .Number;
                s.next = s.next[i..];
            } else {
                if (isLetter(s.next[0])) {
                    // variable or builtin function call
                } else {
                    // operator or special character
                    const op = s.next[0];
                    s.next = s.next[1..];
                    switch (op) {
                        '+' => {
                            s.tokenType = .Infix;
                            s.function = FuncPtr{ .Func2 = add };
                            if (VERBOSE) warn("got add\n");
                        },
                        '-' => {
                            s.tokenType = .Infix;
                            s.function = FuncPtr{ .Func2 = sub };
                            if (VERBOSE) warn("got sub\n");
                        },
                        '*' => {
                            s.tokenType = .Infix;
                            s.function = FuncPtr{ .Func2 = mul };
                        },
                        '/' => {
                            s.tokenType = .Infix;
                            s.function = FuncPtr{ .Func2 = divide };
                        },
                        ' ', '\t', '\n', '\r' => {},
                        else => {
                            s.tokenType = .Error;
                        },
                    }
                }
            }

            if (s.tokenType != .Null)
                break;
        }
    }
};

fn base(s: *State) !*Expr {
    const ret = switch (s.tokenType) {
        .Number => blk: {
            const ret = try s.allocator.create(Expr);
            ret.* = Expr{ .Constant = s.value };
            if (VERBOSE) std.debug.warn("got a constant: {}\n", s.value);
            try s.nextToken();
            break :blk ret;
        },
        else => {
            std.debug.panic("not implemented: {}", s.tokenType);
        },
    };
    return ret;
}

fn is_add_or_sub(funcptr: ?FuncPtr) bool {
    if (funcptr) |fp| {
        return switch (fp) {
            .Func2 => |f| f == add or f == sub,
            else => false,
        };
    }
    return false;
}

fn power(s: *State) !*Expr {
    var sign: i32 = 1;
    while (s.tokenType == .Infix and is_add_or_sub(s.function)) {
        if (s.function) |f| {
            switch (f) {
                .Func2 => |_f| {
                    if (_f == sub) {
                        sign = -sign;
                    }
                },
                else => {},
            }
        }
        try s.nextToken();
    }

    if (sign == 1) {
        return try base(s);
    }

    const ret = try s.allocator.create(Expr);
    ret.* = Expr{
        .Function = Func{
            .Func1 = Func1{
                .parameters = [_]*Expr{try base(s)},
                .function = negate,
            },
        },
    };
    return ret;
}

fn factor(s: *State) !*Expr {
    const ret = try power(s);
    while (s.tokenType == .Infix and if (s.function) |f| f.is(2, pow) else false) {
        std.debug.panic("not implemented");
    }
    return ret;
}

fn term(s: *State) !*Expr {
    var ret = try factor(s);

    while (s.tokenType == .Infix and (if (s.function) |f| (f.is(2, mul) or f.is(2, divide) or f.is(2, fmod)) else false)) {
        const newRet = try s.allocator.create(Expr);
        const t = s.function.?.Func2;
        try s.nextToken();
        newRet.* = Expr{
            .Function = Func{
                .Func2 = Func2{
                    .parameters = [_]*Expr{ ret, try factor(s) },
                    .function = t,
                },
            },
        };
        ret = newRet;
    }

    return ret;
}

fn expr(s: *State) !*Expr {
    var ret = try term(s);

    if (VERBOSE) warn("~~~\nret of expr is {}\ns is: {}\n", ret, s);

    while (s.tokenType == .Infix and (if (s.function) |f| (f.is(2, add) or f.is(2, sub)) else false)) {
        if (VERBOSE) warn("got infix add or subtract\n");

        const newRet = try s.allocator.create(Expr);
        const t = s.function.?.Func2;
        try s.nextToken();
        newRet.* = Expr{
            .Function = Func{
                .Func2 = Func2{
                    .parameters = [_]*Expr{ ret, try term(s) },
                    .function = t,
                },
            },
        };
        ret = newRet;
    }

    return ret;
}

fn list(s: *State) !*Expr {
    var ret = try expr(s);
    while (s.tokenType == .Sep) {
        try s.nextToken();
        const newRet = try s.allocator.create(Expr);
        newRet.* = Expr{
            .Function = Func{
                .Func2 = Func2{
                    .parameters = [_]*Expr{ ret, expr(s) },
                    .function = comma,
                },
            },
        };
        ret = newRet;
    }
    return ret;
}

pub fn compile(allocator: *std.mem.Allocator, expression: []const u8, variables: ?[]Variable) !*Expr {
    var s = State{
        .allocator = allocator,
        .start = expression,
        .next = expression,
        .lookup = variables,
    };

    try s.nextToken();
    if (VERBOSE) warn("after nextToken in compile: {}\n", s);

    const root = try list(&s);
    if (s.tokenType != .End) {
        std.debug.panic("not implemented: not at the end");
    }

    return root;
}

pub fn free_expr(allocator: *std.mem.Allocator, e: *Expr) void {
    switch (e.*) {
        .Function => |func| {
            switch (func) {
                .Func1 => |f| {
                    free_expr(allocator, f.parameters[0]);
                },
                .Func2 => |f| {
                    free_expr(allocator, f.parameters[0]);
                    free_expr(allocator, f.parameters[1]);
                },
                else => {},
            }
        },
        else => {},
    }
    allocator.destroy(e);
}

pub fn interp(allocator: *std.mem.Allocator, expr_str: []const u8) !f64 {
    if (expr_str.len == 0)
        return error.EmptyExpression;

    const expression = try compile(allocator, expr_str, null);
    defer free_expr(allocator, expression);

    return try eval(allocator, expression);
}

pub fn eval(allocator: *std.mem.Allocator, expression: *const Expr) !f64 {
    return switch (expression.*) {
        .Constant => |val| val,
        .Function => |func| func.eval_fn(allocator),
        else => return error.NotImplemented,
    };
}

fn assertInterp(allocator: *std.mem.Allocator, expr_str: []const u8, expected_result: f64) !void {
    const result = try interp(allocator, expr_str);
    if (result != expected_result) {
        std.debug.panic("expected {}, got {}", expected_result, result);
    }
}

const assert = std.debug.assert;

test "expr" {
    const fptr_pow = FuncPtr{ .Func2 = pow };
    const fptr_negate = FuncPtr{ .Func1 = negate };
    assert(fptr_pow.is(2, pow));
    //assert(!fptr_pow.is(1, pow)); // should fail, but doesn't -- function pointer types are all the same?
    assert(!fptr_pow.is(2, add));
    assert(fptr_negate.is(1, negate));
}

test "infix operators" {
    var bytes: [2000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    try assertInterp(allocator, "1", 1.0);
    try assertInterp(allocator, "1+1", 2.0);
    try assertInterp(allocator, "3-3", 0.0);
    try assertInterp(allocator, "3*3", 9.0);
    try assertInterp(allocator, "12/2", 6.0);
}

test "negation" {
    var bytes: [2000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    try assertInterp(allocator, "-1", -1.0);
    try assertInterp(allocator, "-4*5", -20.0);
    try assertInterp(allocator, "--1", 1.0);
}
