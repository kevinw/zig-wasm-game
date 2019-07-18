const std = @import("std");
pub const warn = @import("base.zig").warn;
const VERBOSE = false;

const FnPtr = fn () f64;

const EvalError = error{
    NotImplemented,
    IdentifierNotFound,
    ParseFloat,
    ParserOutOfMemory,
    ExpectedOpenParen,
    InvalidFunctionArgs,
};

fn logNoOp(comptime s: []const u8, args: ...) void {}
fn logVerbose(comptime s: []const u8, args: ...) void {
    @import("root").warn(s ++ "\n", args);
}
const verbose = if (VERBOSE) logVerbose else logNoOp;

/// a wrapper for a function pointer bound to be called later with a set of
/// parameters.  we assume that the runtime-length of the parameters slice
/// is the actual arity of the function pointer, and we cast it to reflect
/// that before calling it.
///
/// TODO: is there a more type-safe way to do this (while remaining
/// relatively succinct?)
pub const Function = struct {
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

pub const Variable = struct {
    name: []const u8,
    address: *f64,

    pub fn init(name: []const u8, address: *f64) Variable {
        return Variable{
            .name = name,
            .address = address,
        };
    }
};

pub const Expr = union(enum) {
    Constant: f64,
    Function: Function,
    Variable: Variable,

    fn IsFunction(s: *Expr) bool {
        return switch (s.*) {
            Function => true,
            else => false,
        };
    }
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
    Variable,
};

inline fn isDigit(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '.';
}

inline fn isLetter(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
}

inline fn isIdentifier(ch: u8) bool {
    return isLetter(ch) or isDigit(ch) or ch == '_';
}

const Func = union(enum) {
    Fn0: fn () f64,
    Fn1: fn (f64) f64,
    Fn2: fn (f64, f64) f64,

    const MAX_ARITY = 2;
};

pub const FuncCall = struct {
    const Self = @This();

    name: []const u8,
    func: Func,

    fn arity(self: *const Self) usize {
        var _arity: usize = switch (self.func) {
            .Fn0 => usize(0),
            .Fn1 => usize(1),
            .Fn2 => usize(2),
        };

        return _arity;
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

fn findVariable(s: *State, name: []const u8) ?Variable {
    for (s.lookup) |variable| {
        if (std.mem.eql(u8, variable.name, name)) {
            return variable;
        }
    }

    return null;
}

pub fn findBuiltin(name: []const u8) ?*const FuncCall {
    for (builtinFunctions) |*f| {
        if (f.eqName(name)) {
            return f;
        }
    }

    return null;
}

const State = struct {
    allocator: *std.mem.Allocator,

    start: []const u8,
    next: []const u8,
    tokenType: TokenType = .Null,

    // TODO: union for value, variable value, or function
    value: f64 = 0,
    bound: ?Variable,
    function: ?*const FuncCall,

    lookup: []const Variable,

    fn init(allocator: *std.mem.Allocator, expression: []const u8, variables: []const Variable) State {
        return State{
            .allocator = allocator,
            .start = expression,
            .next = expression,
            .function = null,
            .bound = null,
            .lookup = variables,
        };
    }

    fn createVariable(self: *State, variable: Variable) EvalError!*Expr {
        const ret = self.allocator.create(Expr) catch return error.ParserOutOfMemory;
        ret.* = Expr{ .Variable = variable };
        return ret;
    }

    fn createConstant(self: *State, constant: f64) EvalError!*Expr {
        const ret = self.allocator.create(Expr) catch return error.ParserOutOfMemory;
        ret.* = Expr{ .Constant = constant };
        return ret;
    }

    fn createFunc(self: *State, fnptr: var, params: ...) EvalError!*Expr {
        // TODO: how to more accurately check for a function pointer argument?
        const name = @typeName(@typeOf(fnptr));
        if (name.len < 3 or name[0] != 'f' or name[1] != 'n' or name[2] != '(')
            @compileError("expected a function pointer, got '" ++ name ++ "'");

        const paramsArray = self.allocator.alloc(*Expr, params.len) catch return EvalError.ParserOutOfMemory;

        comptime var i = 0;
        comptime const len = params.len;
        inline while (i < len) : (i += 1) {
            paramsArray[i] = params[i];
        }

        return self.createFuncWithSlice(fnptr, paramsArray);
    }

    fn createFuncWithSlice(self: *State, fnptr: var, params: []*Expr) EvalError!*Expr {
        const e = self.allocator.create(Expr) catch return error.ParserOutOfMemory;
        e.* = Expr{
            .Function = Function{
                .fptr = @ptrCast(FnPtr, fnptr),
                .params = params,
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
                // Look for a variable or builtin function call.
                if (isLetter(s.next[0])) {
                    const start = s.next;

                    var count: u32 = 0;
                    while (s.next.len > 0 and isIdentifier(s.next[0])) : (count += 1) {
                        s.next = s.next[1..];
                    }
                    const name = start[0..count];

                    if (findVariable(s, name)) |variable| {
                        s.tokenType = .Variable;
                        s.bound = variable;
                        break;
                    }

                    var builtinFunc = findBuiltin(name);
                    if (builtinFunc) |f| {
                        s.tokenType = .Call;
                        s.function = f;
                        break;
                    }

                    warn("error: no builtin function or variable named '{}'\n", name);
                    return error.IdentifierNotFound;
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
                        '^' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("pow").?;
                        },
                        '%' => {
                            s.tokenType = .Infix;
                            s.function = findBuiltin("fmod");
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
                            warn("invalid next char: {}\n", op);
                            s.tokenType = .Error;
                        },
                    }
                }
            }

            if (s.tokenType != .Null) {
                break;
            }
        }
    }
};

fn base(s: *State) EvalError!*Expr {
    switch (s.tokenType) {
        .Number => {
            const ret = s.createConstant(s.value);
            try s.nextToken();
            return ret;
        },
        .Call => {
            try s.nextToken();
            if (s.tokenType != .Open) return error.ExpectedOpenParen;

            const f = s.function.?;
            const arity = f.arity();

            var parameters = std.ArrayList(*Expr).init(s.allocator);
            defer parameters.deinit();

            if (arity == 0) {
                try s.nextToken();
                if (s.tokenType != .Close)
                    return error.InvalidFunctionArgs;
            } else {
                var i: usize = 0;
                arity_loop: while (i < arity) : (i += 1) {
                    try s.nextToken();
                    parameters.append(try expr(s)) catch return error.ParserOutOfMemory;
                    if (s.tokenType != .Sep)
                        break :arity_loop;
                }

                if (s.tokenType != .Close or i != arity - 1)
                    return error.InvalidFunctionArgs;
            }

            try s.nextToken();
            return s.createFuncWithSlice(f.fnPtr(), parameters.toSlice());
        },
        .Open => {
            try s.nextToken();
            const ret = try list(s);
            if (s.tokenType != .Close) {
                s.tokenType = .Error;
            } else {
                try s.nextToken();
            }
            return ret;
        },
        .Variable => {
            const ret = try s.createVariable(s.bound.?);
            try s.nextToken();
            return ret;
        },
        else => {
            @panic("not implemented: tokenType unknown");
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

    return if (sign == 1) try base(s) else s.createFunc(negate, try base(s));
}

fn factor(s: *State) !*Expr {
    var ret = try power(s);

    var neg = false;
    var insertion_maybe: ?*Expr = null;

    switch (ret.*) {
        .Function => |f| {
            if (@ptrToInt(f.fptr) == @ptrToInt(negate)) {
                std.debug.assert(f.params.len == 1);
                const se = f.params[0];
                free_expr(s.allocator, ret);
                ret = se;
                neg = true;
            }
        },
        else => {},
    }

    while (s.tokenType == .Infix and if (s.function) |f| f.eq(pow) else false) {
        const t = s.function.?.fnPtr();
        try s.nextToken();

        if (insertion_maybe) |insertion| {
            switch (insertion.*) {
                .Function => |insertion_f| {
                    var insert = try s.createFunc(t, insertion_f.params[1], try power(s));
                    insertion_f.params[1] = insert;
                    insertion_maybe = insert;
                },
                else => unreachable,
            }
        } else {
            ret = try s.createFunc(t, ret, try power(s));
            insertion_maybe = ret;
        }
    }

    if (neg) {
        ret = try s.createFunc(negate, ret);
    }

    return ret;
}

fn term(s: *State) EvalError!*Expr {
    var ret = try factor(s);

    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(mul) or f.eq(divide) or f.eq(fmod) else false)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.createFunc(f, ret, try factor(s));
    }

    return ret;
}

fn expr(s: *State) EvalError!*Expr {
    var ret = try term(s);

    verbose("~~~\nret of expr is {}\ns is: {}", ret, s);

    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(add) or f.eq(sub) else false)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.createFunc(f, ret, try term(s));
    }

    return ret;
}

fn list(s: *State) !*Expr {
    var ret = try expr(s);
    while (s.tokenType == .Sep) {
        try s.nextToken();
        ret = try s.createFunc(comma, ret, try expr(s));
    }
    return ret;
}

pub fn compile(allocator: *std.mem.Allocator, expression: []const u8, variables: []const Variable) !*Expr {
    var s = State.init(allocator, expression, variables);

    try s.nextToken();
    const root = try list(&s);
    if (s.tokenType != .End) {
        warn("not implemented: not at the end, s.tokenType is {}\n", s.tokenType);
        unreachable;
    }

    return root;
}

pub fn free_expr(allocator: *std.mem.Allocator, e: *Expr) void {
    allocator.destroy(e);
}

pub fn interp(allocator: *std.mem.Allocator, expr_str: []const u8, variables: []const Variable) !f64 {
    if (expr_str.len == 0)
        return error.EmptyExpression;

    const expression = try compile(allocator, expr_str, variables);
    defer free_expr(allocator, expression);

    return try eval(allocator, expression);
}

pub fn eval(allocator: *std.mem.Allocator, expression: *const Expr) !f64 {
    return switch (expression.*) {
        .Constant => |val| val,
        .Function => |func| func.call(allocator),
        .Variable => |bound| bound.address.*,
        else => return error.NotImplemented,
    };
}

fn assertInterp(expr_str: []const u8, expected_result: f64) !void {
    return assertInterpVars(expr_str, expected_result, [_]Variable{});
}

fn assertInterpVars(expr_str: []const u8, expected_result: f64, variables: []const Variable) !void {
    var bytes: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(bytes[0..]);
    const allocator = &fba.allocator;

    const result = try interp(allocator, expr_str, variables);
    if (result != expected_result) {
        warn("expected {}, got {}\n", expected_result, result);
        @panic("does not match");
    }
}

fn fmod(a: f64, b: f64) f64 {
    return std.math.mod(f64, a, b) catch unreachable; // TODO
}

fn pow(base_n: f64, exponent: f64) f64 {
    return std.math.pow(f64, base_n, exponent);
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

fn sin(a: f64) f64 {
    return std.math.sin(a);
}

fn cos(a: f64) f64 {
    return std.math.cos(a);
}

fn max(a: f64, b: f64) f64 {
    return if (a > b) a else b;
}

fn min(a: f64, b: f64) f64 {
    return if (a < b) a else b;
}

fn tan(a: f64) f64 {
    return std.math.tan(a);
}

fn rand() f64 {
    warn("rand is not implemented\n");
    unreachable;
}

pub const builtinFunctions = [_]FuncCall{
    FuncCall.init("abs", fabs),
    FuncCall.init("add", add),
    FuncCall.init("sub", sub),
    FuncCall.init("mul", mul),
    FuncCall.init("divide", divide),
    FuncCall.init("negate", negate),
    FuncCall.init("sin", sin),
    FuncCall.init("cos", cos),
    FuncCall.init("tan", tan),
    FuncCall.init("max", max),
    FuncCall.init("min", min),
    FuncCall.init("pow", pow),
    FuncCall.init("fmod", fmod),
    FuncCall.init("rand", rand),
};

test "infix operators" {
    try assertInterp("1", 1.0);
    try assertInterp("1+1", 2.0);
    try assertInterp("3-3", 0.0);
    try assertInterp("3*3", 9.0);
    try assertInterp("3*3*3", 27.0);
    try assertInterp("12/2", 6.0);
    try assertInterp("5/10", 0.5);
    try assertInterp("3^2", 9);
}

test "parens" {
    try assertInterp("1+3*4", 13.0);
    try assertInterp("1+(3*4)", 13.0);
    try assertInterp("(1+3)*4", 16.0);
}

test "function calls" {
    const assert = std.debug.assert;
    assert(findBuiltin("foo") == null);
    assert(findBuiltin("abs") != null);
    assert(findBuiltin("abs").?.eqName("abs"));

    const value: f64 = -5.0;
    assert(findBuiltin("abs").?.call(value) == 5.0);

    try assertInterp("abs(1)", 1.0);
    try assertInterp("abs(-42)", 42.0);

    try assertInterp("sin(1)", 0.8414709848078965);
    try assertInterp("cos(1)", 0.5403023058681398);
    try assertInterp("max(42, 41)", 42.0);
    try assertInterp("max(41, 42)", 42.0);
    try assertInterp("max(-50, 50)", 50.0);
}

test "negation" {
    try assertInterp("-1", -1.0);
    try assertInterp("-4*5", -20.0);
    try assertInterp("-1*-1", 1.0);
    try assertInterp("--1", 1.0);
    try assertInterp("--1", 1.0);
}

var PI: f64 = std.math.pi;

const testVars = [_]Variable{Variable{ .name = "PI", .address = &PI }};

test "variables" {
    try assertInterpVars("PI", 3.141592653589793, testVars[0..]);

    var x: f64 = 0;
    var xPtr = &x;
    const vars = [_]Variable{Variable.init("x", xPtr)};

    while (x < 20) {
        x += 1.5;
        try assertInterpVars("x", x, vars);
    }
}
