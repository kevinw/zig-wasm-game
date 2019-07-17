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
            else => |n| std.debug.panic("got {} params", n),
        };
    }
};

const Expr = union(enum) {
    Constant: f64,
    Function: Function,

    fn initFunction(allocator: *std.mem.Allocator, fptr: var, params: []*Expr) EvalError!Expr {
        return Expr{
            .Function = Function{
                .fptr = @ptrCast(FnPtr, fptr),
                .params = params,
            },
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
};

inline fn isDigit(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '.';
}

inline fn isLetter(ch: u8) bool {
    return ch >= 'a' and ch <= 'z';
}

//const builtinFunctions = [_]FuncCall{FuncCall{ .name = "abs", .function = FuncPtr{ .Func1 = fabs } }};

//fn findBuiltin(s: *const State, name: []const u8) ?*const FuncCall {
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
    function: ?fn () f64,

    value: f64 = 0,

    fn create_func_expr(self: *State, fnptr: var, params: []*Expr) EvalError!*Expr {
        const e = self.allocator.create(Expr) catch |e| {
            return error.ParserOutOfMemory;
        };
        e.* = try Expr.initFunction(self.allocator, fnptr, params);
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

                    std.debug.panic("todo: find builtin named {}", functionName);

                    //var variable = findBuiltin(s, functionName);
                    //if (variable) |v| {
                    //    s.tokenType = .Call;
                    //    s.function = (variable orelse unreachable).function;
                    //    if (VERBOSE) warn("parsed function {} {}", functionName, s.function);
                    //} else {
                    //    s.tokenType = .Error;
                    //}
                } else {
                    // operator or special character
                    const op = s.next[0];
                    s.next = s.next[1..];
                    switch (op) {
                        '+' => {
                            s.tokenType = .Infix;
                            s.function = @ptrCast(FnPtr, add);
                        },
                        '-' => {
                            s.tokenType = .Infix;
                            s.function = @ptrCast(FnPtr, sub);
                        },
                        '*' => {
                            s.tokenType = .Infix;
                            s.function = @ptrCast(FnPtr, mul);
                        },
                        '/' => {
                            s.tokenType = .Infix;
                            s.function = @ptrCast(FnPtr, divide);
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

inline fn fnsEq(a: var, b: var) bool {
    return @ptrCast(@typeOf(b), a) == b;
}

fn power(s: *State) !*Expr {
    var sign: i32 = 1;
    while (s.tokenType == .Infix and (if (s.function) |f| fnsEq(f, add) or fnsEq(f, sub) else false)) {
        if (s.function) |f| {
            if (fnsEq(f, sub)) {
                sign = -sign;
            }
        }
        try s.nextToken();
    }

    if (sign == 1) {
        return try base(s);
    } else {
        var params = s.allocator.alloc(*Expr, 1) catch return EvalError.ParserOutOfMemory;
        params[0] = try base(s);
        return s.create_func_expr(negate, params);
    }
}

fn factor(s: *State) !*Expr {
    var ret = try power(s);

    while (s.tokenType == .Infix and if (s.function) |f| fnsEq(f, pow) else false) {
        std.debug.panic("not implemented");
    }

    return ret;
}

fn term(s: *State) EvalError!*Expr {
    var ret = try factor(s);

    while (s.tokenType == .Infix and (if (s.function) |f| fnsEq(f, mul) or fnsEq(f, divide) or fnsEq(f, fmod) else false)) {
        const t = s.function.?;
        try s.nextToken();

        var params = s.allocator.alloc(*Expr, 2) catch return EvalError.ParserOutOfMemory;
        params[0] = ret;
        params[1] = try factor(s);
        ret = try s.create_func_expr(t, params);
    }

    return ret;
}

fn expr(s: *State) EvalError!*Expr {
    var ret = try term(s);

    verbose("~~~\nret of expr is {}\ns is: {}", ret, s);

    while (s.tokenType == .Infix and (if (s.function) |f| fnsEq(f, add) or fnsEq(f, sub) else false)) {
        const t = s.function.?;
        try s.nextToken();

        var params = s.allocator.alloc(*Expr, 2) catch return EvalError.ParserOutOfMemory;
        params[0] = ret;
        params[1] = try term(s);
        ret = try s.create_func_expr(t, params);
        verbose("RET IS {}", ret);
    }

    return ret;
}

fn list(s: *State) !*Expr {
    var ret = try expr(s);
    while (s.tokenType == .Sep) {
        try s.nextToken();

        var params = s.allocator.alloc(*Expr, 2) catch return EvalError.ParserOutOfMemory;
        params[0] = ret;
        params[1] = try expr(s);
        ret = try s.create_func_expr(comma, params[0..]);
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
    //defer free_expr(allocator, expression);

    return try eval(allocator, expression);
}

pub fn eval(allocator: *std.mem.Allocator, expression: *const Expr) !f64 {
    return switch (expression.*) {
        .Constant => |val| val,
        .Function => |func| func.call(allocator),
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

test "infix operators" {
    var bytes: [4000]u8 = undefined;
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
    try assertInterp(allocator, "--1", 1.0);
}

test "variables" {
    var bytes: [2000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;
}
