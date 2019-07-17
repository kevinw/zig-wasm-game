const std = @import("std");
const warn = std.debug.warn;
const VERBOSE = false;

const FnPtr = fn () f64;

const EvalError = error{
    NotImplemented,
    ParseFloat,
    ParserOutOfMemory,
};

fn logNoOp(comptime s: []const u8, args: ...) void {}
fn logVerbose(comptime s: []const u8, args: ...) void {
    std.debug.warn(s ++ "\n", args);
}
const verbose = if (VERBOSE) logVerbose else logNoOp;

/// a wrapper for a function pointer bound to be called later with a set of
/// parameters.  we assume that the runtime-length of the parameters slice
/// is the actual arity of the function pointer, and we cast it to reflect
/// that before calling it.
///
/// TODO: is there a more type-safe way to do this (while remaining
/// relatively succinct?)
const Function = struct {
    const Self = @This();

    fptr: fn () f64,
    params: []*Expr,

    fn call(self: *const Self, allocator: *std.mem.Allocator) EvalError!f64 {
        const f = self.fptr;
        return switch (self.params.len) {
            0 => self.fptr(),
            1 => @ptrCast(fn (f64) f64, f)(try eval(allocator, self.params[0])),
            2 => @ptrCast(fn (f64, f64) f64, f)(try eval(allocator, self.params[0]), try eval(allocator, self.params[1])),
            3 => @ptrCast(fn (f64, f64, f64) f64, f)(try eval(allocator, self.params[0]), try eval(allocator, self.params[1]), try eval(allocator, self.params[2])),
            else => unreachable,
        };
    }
};

const Expr = union(enum) {
    Constant: f64,
    Function: Function,
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

const Func = union(enum) {
    Fn0: fn () f64,
    Fn1: fn (f64) f64,
    Fn2: fn (f64, f64) f64,

    const MAX_ARITY = 2;
};

const FuncCall = struct {
    const Self = @This();

    name: []const u8,
    func: Func,

    fn arity(self: *const Self) usize {
        return switch (self.func) {
            .Fn0 => 0,
            .Fn1 => 1,
            .Fn2 => 2,
        };
    }

    fn call(self: *const Self, params: ...) f64 {
        comptime const N = params.len;
        var args: [Func.MAX_ARITY]f64 = undefined;

        comptime var i = 0;
        comptime const len = params.len;
        inline while (i < len) : (i += 1) args[i] = params[i];

        return switch (self.func) {
            .Fn0 => |f| f(),
            .Fn1 => |f| f(args[0]),
            .Fn2 => |f| f(args[0], args[1]),
        };
    }

    fn eq(self: *const Self, function: var) bool {
        return switch (self.func) {
            .Fn0 => |f| @ptrToInt(f) == @ptrToInt(function),
            .Fn1 => |f| @ptrToInt(f) == @ptrToInt(function),
            .Fn2 => |f| @ptrToInt(f) == @ptrToInt(function),
        };
    }

    fn fnPtr(self: *const Self) FnPtr {
        return switch (self.func) {
            .Fn0 => |f| @ptrCast(FnPtr, f),
            .Fn1 => |f| @ptrCast(FnPtr, f),
            .Fn2 => |f| @ptrCast(FnPtr, f),
        };
    }

    fn eqName(self: *const Self, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }

    fn init(name: []const u8, function: var) FuncCall {
        return FuncCall{
            .name = name,
            .func = switch (@typeOf(function)) {
                fn () f64 => Func{ .Fn0 = function },
                fn (f64) f64 => Func{ .Fn1 = function },
                fn (f64, f64) f64 => Func{ .Fn2 = function },
                else => unreachable,
            },
        };
    }
};

const builtinFunctions = [_]FuncCall{
    FuncCall.init("abs", fabs),
    FuncCall.init("add", add),
    FuncCall.init("sub", sub),
    FuncCall.init("mul", mul),
    FuncCall.init("divide", divide),
};

fn findBuiltin(name: []const u8) ?*const FuncCall {
    for (builtinFunctions) |*f| {
        if (f.eqName(name)) {
            return f;
        }
    }

    return null;
}
//if (VERBOSE) warn("finding builtin {}\n", name);
//for (builtinFunctions) |builtin_func| {
//if (std.mem.eql(u8, builtin_func.name, name)) {
//if (VERBOSE) warn("  found: {}\n", builtin_func);
//return &builtin_func;
//}
//}
//if (VERBOSE) warn("  DID NOT FIND\n");
//return null;
//}

const State = struct {
    allocator: *std.mem.Allocator,

    start: []const u8,
    next: []const u8,
    tokenType: TokenType = .Null,
    function: ?*const FuncCall,

    value: f64 = 0,

    fn create_func(self: *State, fnptr: var, params: ...) EvalError!*Expr {
        const paramsArray = self.allocator.alloc(*Expr, params.len) catch return EvalError.ParserOutOfMemory;

        comptime var i = 0;
        comptime const len = params.len;
        inline while (i < len) : (i += 1) {
            paramsArray[i] = params[i];
        }

        const e = self.allocator.create(Expr) catch |e| {
            return error.ParserOutOfMemory;
        };
        e.* = Expr{
            .Function = Function{
                .fptr = @ptrCast(FnPtr, fnptr),
                .params = paramsArray,
            },
        };
        return e;
    }

    fn nextToken(s: *State) EvalError!void {
        s.tokenType = .Null;
        var debugCount: u16 = 0;
        while (true) {
            debugCount += 1;

            if (s.next.len == 0) {
                verbose("none left, setting end");
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
                verbose("parsed float from '{}': {}", s.next[0..i], s.value);
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

                    var builtinFunc = findBuiltin(functionName);
                    if (builtinFunc) |f| {
                        s.tokenType = .Call;
                        s.function = f;
                    } else {
                        warn("no builtin named {}\n", functionName);
                        s.tokenType = .Error;
                    }
                } else {
                    // operator or special character
                    const op = s.next[0];
                    s.next = s.next[1..];
                    switch (op) {
                        '+' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("add").?;
                        },
                        '-' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("sub").?;
                        },
                        '*' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("mul").?;
                        },
                        '/' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("divide").?;
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
    switch (s.tokenType) {
        .Number => blk: {
            const ret = s.allocator.create(Expr) catch return error.ParserOutOfMemory;
            ret.* = Expr{ .Constant = s.value };
            try s.nextToken();
            return ret;
        },
        .Call => blk2: {
            const ret = s.allocator.create(Expr) catch return error.ParserOutOfMemory;
            //ret.* = Expr{ .Function = s.function orelse unreachable };
            try s.nextToken();
            if (s.tokenType != .Open) {
                s.tokenType = .Error;
            } else {
                try s.nextToken();

                const f = s.function.?;
                const arity: u8 = 0;
                std.debug.panic("arity");

                //if (VERBOSE) warn("ARITY {} for {}", arity, f);

                //var parameters = std.ArrayList(*Expr).init(s.allocator);
                //defer parameters.deinit();

                //var i: u8 = 0;
                //arity_loop: while (i < arity) : (i += 1) {
                //    try s.nextToken();
                //    parameters.append(try expr(s)) catch |e| {
                //        return error.ParserOutOfMemory;
                //    };
                //    if (s.tokenType != .Sep) {
                //        break :arity_loop;
                //    }
                //}
                //if (s.tokenType != .Close or i != arity - 1) {
                //    s.tokenType = .Error;
                //} else {
                //    try s.nextToken();
                //}
                //} else if (arity == 2) {
                //    switch (f) {
                //        .Func2 => |ff| {
                //            ret.* = Expr{ .Function = Func2.initWithParameters(ff, parameters.toSlice()) };
                //        },
                //        else => unreachable,
                //    }
                //}
            }
            return ret;
        },
        .Open => open: {
            try s.nextToken();
            const ret = try list(s);
            if (s.tokenType != .Close) {
                s.tokenType = .Error;
            } else {
                try s.nextToken();
            }
            return ret;
        },
        else => {
            std.debug.panic("not implemented: {}", s.tokenType);
        },
    }

    unreachable;
}

fn power(s: *State) !*Expr {
    var sign: i32 = 1;
    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(add) or f.eq(sub) else false)) {
        if (s.function) |f| {
            if (f.eq(sub)) {
                sign = -sign;
            }
        }
        try s.nextToken();
    }

    return if (sign == 1) try base(s) else s.create_func(negate, try base(s));
}

fn factor(s: *State) !*Expr {
    var ret = try power(s);

    while (s.tokenType == .Infix and if (s.function) |f| f.eq(pow) else false) {
        std.debug.panic("not implemented");
    }

    return ret;
}

fn term(s: *State) EvalError!*Expr {
    var ret = try factor(s);

    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(mul) or f.eq(divide) or f.eq(fmod) else false)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.create_func(f, ret, try factor(s));
    }

    return ret;
}

fn expr(s: *State) EvalError!*Expr {
    var ret = try term(s);

    verbose("~~~\nret of expr is {}\ns is: {}", ret, s);

    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(add) or f.eq(sub) else false)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.create_func(f, ret, try term(s));
    }

    return ret;
}

fn list(s: *State) !*Expr {
    var ret = try expr(s);
    while (s.tokenType == .Sep) {
        try s.nextToken();
        ret = try s.create_func(comma, ret, try expr(s));
    }
    return ret;
}

pub fn compile(allocator: *std.mem.Allocator, expression: []const u8) !*Expr {
    var s = State{
        .allocator = allocator,
        .start = expression,
        .next = expression,
        .function = null,
    };

    try s.nextToken();
    const root = try list(&s);
    if (s.tokenType != .End) {
        std.debug.panic("not implemented: not at the end");
    }

    return root;
}

pub fn free_expr(allocator: *std.mem.Allocator, e: *Expr) void {
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
        .Function => |func| func.call(allocator),
        else => return error.NotImplemented,
    };
}

fn assertInterp(expr_str: []const u8, expected_result: f64) !void {
    var bytes: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(bytes[0..]);
    const allocator = &fba.allocator;

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

test "infix operators" {
    try assertInterp("1", 1.0);
    try assertInterp("1+1", 2.0);
    try assertInterp("3-3", 0.0);
    try assertInterp("3*3", 9.0);
    try assertInterp("3*3*3", 27.0);
    try assertInterp("12/2", 6.0);
    try assertInterp("5/10", 0.5);
}

test "parens" {
    try assertInterp("1+3*4", 13.0);
    try assertInterp("1+(3*4)", 13.0);
    try assertInterp("(1+3)*4", 16.0);
}

const assert = std.debug.assert;

test "function call" {
    assert(findBuiltin("foo") == null);
    assert(findBuiltin("abs") != null);
    assert(findBuiltin("abs").?.eqName("abs"));

    const value: f64 = -5.0;
    assert(findBuiltin("abs").?.call(value) == 5.0);

    //try assertInterp("abs(1)", 1.0);
    //try assertInterp("abs(-42)", 42.0);
}

test "negation" {
    try assertInterp("-1", -1.0);
    try assertInterp("-4*5", -20.0);
    try assertInterp("-1*-1", 1.0);
    try assertInterp("--1", 1.0);
    try assertInterp("--1", 1.0);
}
