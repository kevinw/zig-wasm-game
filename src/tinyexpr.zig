const std = @import("std");
const warn = std.debug.warn;
const VERBOSE = false;

fn _FuncPtr(comptime arity: u8) type {
    return switch (arity) {
        0 => fn () f64,
        1 => fn (a: f64) f64,
        2 => fn (a: f64, b: f64) f64,
        else => unreachable,
    };
}

fn _Func(comptime arity: u8) type {
    return struct {
        const Self = @This();
        pub const FP = _FuncPtr(arity);

        parameters: if (arity > 0) [arity]*Expr else void,
        function: FP,

        fn initWithParameters(f: FP, paramsSlice: []*Expr) Self {
            if (arity == 0)
                return Self{ .function = f, .parameters = undefined };
            const params = switch (arity) {
                1 => [_]*Expr{paramsSlice[0]},
                2 => [_]*Expr{ paramsSlice[0], paramsSlice[1] },
                else => unreachable,
            };
            return Self{
                .function = f,
                .parameters = params,
            };
        }
    };
}

const Func0 = _Func(0);
const Func1 = _Func(1);
const Func2 = _Func(2);

const Func = union(enum) {
    const Self = @This();

    fn initWithParams(arity: u8, fp: var, paramsSlice: []*const Expr) Self {
        return switch (arity) {
            0 => Self{ .Func0 = Func0.initWithParameters(fp, paramsSlice) },
            1 => Self{ .Func1 = Func1.initWithParameters(fp, paramsSlice) },
            2 => Self{ .Func2 = Func2.initWithParameters(fp, paramsSlice) },
            else => unreachable,
        };
    }

    Func0: Func0,
    Func1: Func1,
    Func2: Func2,
};

const FuncPtr = union(enum) {
    Func0: _FuncPtr(0),
    Func1: _FuncPtr(1),
    Func2: _FuncPtr(2),

    //fn getArity(self: *const FuncPtr) u8 {
    //return switch (self.*) {
    //.Func0 => 0,
    //.Func1 => 1,
    //.Func2 => 2,
    //};
    //}

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

const EvalError = error{
    NotImplemented,
    ParseFloat,
    ParserOutOfMemory,
};

fn eval_fn(self: Func, allocator: *std.mem.Allocator) EvalError!f64 {
    return switch (self) {
        .Func0 => |f| f.function(),
        .Func1 => |f| f.function(try eval(allocator, f.parameters[0])),
        .Func2 => |f| f.function(try eval(allocator, f.parameters[0]), try eval(allocator, f.parameters[1])),
        else => return EvalError.NotImplemented,
    };
}

const ExprType = enum {
    Constant,
    Function,
};

const Expr = union(ExprType) {
    Constant: f64,
    Function: Func,
};

const FuncCall = struct {
    name: []const u8,
    function: FuncPtr,
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
    Call,
};

inline fn isDigit(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '.';
}

inline fn isLetter(ch: u8) bool {
    return ch >= 'a' and ch <= 'z';
}

const builtinFunctions = [_]FuncCall{FuncCall{ .name = "abs", .function = FuncPtr{ .Func1 = fabs } }};

fn findBuiltin(s: *const State, name: []const u8) ?*const FuncCall {
    if (VERBOSE) warn("finding builtin {}\n", name);
    for (builtinFunctions) |builtin_func| {
        if (std.mem.eql(u8, builtin_func.name, name)) {
            if (VERBOSE) warn("  found: {}\n", builtin_func);
            return &builtin_func;
        }
    }

    if (VERBOSE) warn("  DID NOT FIND\n");
    return null;
}

const State = struct {
    allocator: *std.mem.Allocator,

    start: []const u8,
    next: []const u8,
    tokenType: TokenType = .Null,

    value: f64 = 0,
    function: ?FuncPtr = null,

    fn create_func_expr(self: *State, func: Func) EvalError!*Expr {
        const e = self.allocator.create(Expr) catch |e| {
            return error.ParserOutOfMemory;
        };
        e.* = Expr{ .Function = func };
        return e;
    }

    fn nextToken(s: *State) EvalError!void {
        s.tokenType = .Null;
        var debugCount: u16 = 0;
        while (true) {
            if (VERBOSE) std.debug.warn("----\n{} nextToken loop, next is: '{}'\n", debugCount, s.next);
            debugCount += 1;

            if (s.next.len == 0) {
                if (VERBOSE) warn("none left, setting end\n");
                s.tokenType = .End;
                return;
            }

            // Try reading a number.
            if (isDigit(s.next[0])) {
                var i: usize = 0;
                while (i < s.next.len and isDigit(s.next[i])) : (i += 1) {}
                s.value = std.fmt.parseFloat(f64, s.next[0..i]) catch |err| {
                    return error.ParseFloat;
                };
                if (VERBOSE) warn("parsed float from '{}': {}\n", s.next[0..i], s.value);
                s.tokenType = .Number;
                s.next = s.next[i..];
            } else {
                if (isLetter(s.next[0])) {
                    // variable or builtin function call
                    const start = s.next;

                    //while ((s->next[0] >= 'a' && s->next[0] <= 'z') || (s->next[0] >= '0' && s->next[0] <= '9') || (s->next[0] == '_')) s->next++;

                    var count: u32 = 0;
                    while (isLetter(s.next[0]) or isDigit(s.next[0]) or s.next[0] == '_') {
                        s.next = s.next[1..];
                        count += 1;
                    }

                    const functionName = start[0..count];

                    var variable = findBuiltin(s, functionName);
                    if (variable) |v| {
                        s.tokenType = .Call;
                        s.function = (variable orelse unreachable).function;
                        if (VERBOSE) warn("parsed function {} {}", functionName, s.function);
                    } else {
                        s.tokenType = .Error;
                    }
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
                        '(' => {
                            s.tokenType = .Open;
                        },
                        ')' => {
                            s.tokenType = .Close;
                        },
                        ',' => {
                            s.tokenType = .Sep;
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

fn base(s: *State) EvalError!*Expr {
    if (VERBOSE) warn("----------BASE {}", s);
    const ret = switch (s.tokenType) {
        .Number => blk: {
            const ret = s.allocator.create(Expr) catch |e| return error.ParserOutOfMemory;
            ret.* = Expr{ .Constant = s.value };
            if (VERBOSE) warn("got a constant: {}\n", s.value);
            try s.nextToken();
            break :blk ret;
        },
        .Call => blk2: {
            const ret = s.allocator.create(Expr) catch |e| {
                return error.ParserOutOfMemory;
            };
            //ret.* = Expr{ .Function = s.function orelse unreachable };
            try s.nextToken();
            if (s.tokenType != .Open) {
                s.tokenType = .Error;
            } else {
                try s.nextToken();

                const f = s.function orelse unreachable;
                const arity: u8 = switch (f) {
                    .Func0 => u8(0),
                    .Func1 => u8(1),
                    .Func2 => u8(2),
                    else => unreachable,
                };

                if (VERBOSE) warn("ARITY {} for {}", arity, f);

                var parameters = std.ArrayList(*Expr).init(s.allocator);
                defer parameters.deinit();

                var i: u8 = 0;
                arity_loop: while (i < arity) : (i += 1) {
                    try s.nextToken();
                    parameters.append(try expr(s)) catch |e| {
                        return error.ParserOutOfMemory;
                    };
                    if (s.tokenType != .Sep) {
                        break :arity_loop;
                    }
                }
                if (s.tokenType != .Close or i != arity - 1) {
                    s.tokenType = .Error;
                } else {
                    try s.nextToken();
                }

                if (arity == 0) {
                    switch (f) {
                        .Func0 => |ff| {
                            ret.* = Expr{ .Function = Func0.initWithParameters(ff, parameters.toSlice()) };
                        },
                        else => unreachable,
                    }
                } else if (arity == 1) {
                    switch (f) {
                        .Func1 => |ff| {
                            ret.* = Expr{ .Function = Func1.initWithParameters(ff, parameters.toSlice()) };
                        },
                        else => unreachable,
                    }
                } else if (arity == 2) {
                    switch (f) {
                        .Func2 => |ff| {
                            ret.* = Expr{ .Function = Func2.initWithParameters(ff, parameters.toSlice()) };
                        },
                        else => unreachable,
                    }
                }
            }
            break :blk2 ret;
        },
        .Open => open: {
            try s.nextToken();
            const ret = try list(s);
            if (s.tokenType != .Close) {
                s.tokenType = .Error;
            } else {
                try s.nextToken();
            }
            break :open ret;
        },
        else => {
            std.debug.panic("not implemented: {}", s.tokenType);
        },
    };
    return ret;
}

fn power(s: *State) !*Expr {
    var sign: i32 = 1;
    while (s.tokenType == .Infix and (if (s.function) |f| (f.is(2, add) or f.is(2, sub)) else false)) {
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

    return s.create_func_expr(Func{
        .Func1 = Func1{
            .parameters = [_]*Expr{try base(s)},
            .function = negate,
        },
    });
}

fn factor(s: *State) !*Expr {
    var ret = try power(s);

    while (s.tokenType == .Infix and if (s.function) |f| f.is(2, pow) else false) {
        std.debug.panic("not implemented");
    }

    return ret;
}

fn term(s: *State) EvalError!*Expr {
    var ret = try factor(s);

    while (s.tokenType == .Infix and (if (s.function) |f| (f.is(2, mul) or f.is(2, divide) or f.is(2, fmod)) else false)) {
        const t = s.function.?.Func2;
        try s.nextToken();
        ret = try s.create_func_expr(Func{
            .Func2 = Func2{
                .parameters = [_]*Expr{ ret, try factor(s) },
                .function = t,
            },
        });
    }

    return ret;
}

fn expr(s: *State) EvalError!*Expr {
    var ret = try term(s);

    if (VERBOSE) warn("~~~\nret of expr is {}\ns is: {}\n", ret, s);

    while (s.tokenType == .Infix and (if (s.function) |f| (f.is(2, add) or f.is(2, sub)) else false)) {
        if (VERBOSE) warn("got infix add or subtract\n");

        const t = s.function.?.Func2;
        try s.nextToken();
        ret = try s.create_func_expr(Func{
            .Func2 = Func2{
                .parameters = [_]*Expr{ ret, try term(s) },
                .function = t,
            },
        });
    }

    return ret;
}

fn list(s: *State) !*Expr {
    var ret = try expr(s);
    while (s.tokenType == .Sep) {
        try s.nextToken();
        ret = try s.create_func_expr(Func{
            .Func2 = Func2{
                .parameters = [_]*Expr{ ret, expr(s) },
                .function = comma,
            },
        });
    }
    return ret;
}

pub fn compile(allocator: *std.mem.Allocator, expression: []const u8) !*Expr {
    var s = State{
        .allocator = allocator,
        .start = expression,
        .next = expression,
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

    const expression = try compile(allocator, expr_str);
    defer free_expr(allocator, expression);

    return try eval(allocator, expression);
}

pub fn eval(allocator: *std.mem.Allocator, expression: *const Expr) !f64 {
    return switch (expression.*) {
        .Constant => |val| val,
        .Function => |func| eval_fn(func, allocator),
        else => return error.NotImplemented,
    };
}

fn assertInterp(allocator: *std.mem.Allocator, expr_str: []const u8, expected_result: f64) !void {
    const result = try interp(allocator, expr_str);
    if (result != expected_result) {
        std.debug.panic("expected {}, got {}", expected_result, result);
    }
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

fn fabs(a: f64) f64 {
    return if (a < 0) -a else a;
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

test "variables" {
    var bytes: [2000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;
    try assertInterp(allocator, "--1", 1.0);
}
