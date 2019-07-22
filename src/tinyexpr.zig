const std = @import("std");
pub const warn = @import("base.zig").warn;
const VERBOSE = false;

const FnPtr = fn () f64;

const EvalError = error{
    NotImplemented,
    IdentifierNotFound,
    OutOfMemory,
    ParseFloat,
    ParseError,
    EmptyExpression,
    ExpectedOpenParen,
    InvalidFunctionArgs,
    HexNumberTooLong,
    InvalidCharacter,
    WrongNumberOfFunctionArgs,
    InvalidBuiltin,
};

fn log(comptime s: []const u8, args: ...) void {
    warn(s ++ "\n", args);
}

fn logNoOp(comptime s: []const u8, args: ...) void {}
const logVerbose = log;
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

    pub fn deinit(self: *Expr, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .Function => |*f| allocator.free(f.params),
            else => {},
        }
        allocator.destroy(self);
    }
};

const TokenType = enum {
    Null,
    End,
    Number,
    Infix,
    InfixFunctionApply,
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

    fn in(self_maybe: ?*const Self, args: ...) bool {
        if (self_maybe) |self| {
            if (args.len == 0) return false;
            if (self.eq(args[0]) or FuncCall.in(self_maybe, args[1..]))
                return true;
        } else {
            return false;
        }
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
        const ret = try self.allocator.create(Expr);
        ret.* = Expr{ .Variable = variable };
        return ret;
    }

    fn createConstant(self: *State, constant: f64) EvalError!*Expr {
        const ret = try self.allocator.create(Expr);
        ret.* = Expr{ .Constant = constant };
        return ret;
    }

    fn createFunc(self: *State, fnptr: var, params: ...) EvalError!*Expr {
        // TODO: how to more accurately check for a function pointer argument?
        const name = @typeName(@typeOf(fnptr));
        if (name.len < 3 or name[0] != 'f' or name[1] != 'n' or name[2] != '(')
            @compileError("expected a function pointer, got '" ++ name ++ "'");

        const paramsArray = try self.allocator.alloc(*Expr, params.len);

        comptime var i = 0;
        comptime const len = params.len;
        inline while (i < len) : (i += 1) {
            paramsArray[i] = params[i];
        }

        return self.createFuncWithSlice(fnptr, paramsArray);
    }

    fn createFuncWithSlice(self: *State, fnptr: var, params: []*Expr) EvalError!*Expr {
        const e = try self.allocator.create(Expr);
        e.* = Expr{
            .Function = Function{
                .fptr = @ptrCast(FnPtr, fnptr),
                .params = params,
            },
        };
        return e;
    }

    fn setBuiltinInfixToken(self: *State, builtinFuncName: []const u8, peek: bool, num_chars: u8) NextOp {
        if (!peek) {
            if (findBuiltin(builtinFuncName)) |f| {
                self.function = f;
            } else {
                warn("error: expected to be able to find builtin named {} at compile-time\n", builtinFuncName);
                unreachable;
            }
        }

        return NextOp.init(.Infix, num_chars);
    }

    const NextOp = struct {
        token_type: TokenType,
        num_chars: u8 = 1,

        fn init(token_type: TokenType, num_chars: u8) NextOp {
            return NextOp{
                .token_type = token_type,
                .num_chars = num_chars,
            };
        }
    };

    fn nextOperator(s: *State, op: u8, peek: bool) NextOp {
        return switch (op) {
            '+' => s.setBuiltinInfixToken("add", peek, 1),
            '-' => s.setBuiltinInfixToken("sub", peek, 1),
            '*' => s.setBuiltinInfixToken("mul", peek, 1),
            '/' => s.setBuiltinInfixToken("divide", peek, 1),
            '%' => s.setBuiltinInfixToken("fmod", peek, 1),
            //'^' => s.setBuiltinInfixToken("pow", peek, 1),

            '|' => s.setBuiltinInfixToken("bitwise_or", peek, 1),
            '&' => s.setBuiltinInfixToken("bitwise_and", peek, 1),
            '~' => s.setBuiltinInfixToken("bitwise_not", peek, 1),
            '^' => s.setBuiltinInfixToken("bitwise_xor", peek, 1),

            '$' => NextOp.init(.InfixFunctionApply, 1),

            '<' => if (s.next.len > 1 and s.next[1] == '<')
                s.setBuiltinInfixToken("shift_left", peek, 2)
            else
                NextOp.init(.Error, 1),

            '(' => NextOp.init(.Open, 1),
            ')' => NextOp.init(.Close, 1),
            ',' => NextOp.init(.Sep, 1),

            ' ', '\t', '\n', '\r' => NextOp.init(.Null, 1),

            else => else_blk: {
                warn("invalid next char: {c}\n", op);
                break :else_blk NextOp.init(.Error, 1);
            },
        };
    }

    fn peekNextToken(s: *State) TokenType {
        var next = s.next;

        if (next.len == 0) return .End;

        if (isDigit(next[0])) return .Number;

        if (isLetter(next[0])) return .Call; // or .Variable...

        var tokenType: TokenType = .Null;
        while (next.len > 0 and tokenType == .Null) {
            const next_op = s.nextOperator(next[0], true);
            tokenType = next_op.token_type;
            next = next[next_op.num_chars..];
        }

        return tokenType;
    }

    fn currentCharIndex(s: *State) u16 {
        const count = @ptrToInt(s.next.ptr) - @ptrToInt(s.start.ptr);
        return @intCast(u16, count);
    }

    fn isHexDigit(byte: u8) bool {
        return (byte >= '0' and byte <= '9') or
            (byte >= 'a' and byte <= 'f') or
            (byte >= 'A' and byte <= 'F');
    }

    /// Convert a hex string to a 32bit number (max 8 hex digits)
    fn hexToInt(_hex: []const u8) !u32 {
        // thanks https://stackoverflow.com/questions/10156409/convert-hex-string-char-to-int/39052987#39052987
        var hex = _hex;
        if (hex.len > 8) {
            log("error trying to parse hex '{}'", hex);
            return error.HexNumberTooLong;
        }

        var val: u32 = 0;
        while (hex.len > 0) {
            var byte = hex[0];
            hex = hex[1..];

            if (byte >= '0' and byte <= '9') {
                byte = byte - '0';
            } else if (byte >= 'a' and byte <= 'f') {
                byte = byte - 'a' + 10;
            } else if (byte >= 'A' and byte <= 'F') {
                byte = byte - 'A' + 10;
            } else {
                return error.InvalidCharacter;
            }

            val = (val << 4) | (byte & 0xF);
        }

        return val;
    }

    fn nextToken(s: *State) EvalError!void {
        s.tokenType = .Null;
        while (true) {
            if (s.next.len == 0) {
                s.tokenType = .End;
                return;
            }

            // Try reading a number.
            if (isDigit(s.next[0])) {
                if (s.next.len > 2 and s.next[0] == '0' and s.next[1] == 'x') {
                    // hex digit
                    s.next = s.next[2..];

                    var i: usize = 0;
                    while (i < s.next.len and isHexDigit(s.next[i])) : (i += 1) {}
                    const hexString = s.next[0..i];
                    s.value = @intToFloat(f64, try hexToInt(hexString));
                    s.tokenType = .Number;
                    s.next = s.next[i..];
                } else {
                    // base 10
                    var i: usize = 0;
                    while (i < s.next.len and isDigit(s.next[i])) : (i += 1) {}
                    s.value = std.fmt.parseFloat(f64, s.next[0..i]) catch return error.ParseFloat;
                    verbose("parsed float from '{}': {}", s.next[0..i], s.value);
                    s.tokenType = .Number;
                    s.next = s.next[i..];
                }
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

                    const next_op = s.nextOperator(op, false);
                    s.tokenType = next_op.token_type;
                    s.next = s.next[next_op.num_chars..];
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
                if (s.tokenType != .Close) {
                    log("expected a closing paren for arity-0 function {}", f);
                    return error.InvalidFunctionArgs;
                }
            } else {
                var i: usize = 0;
                arity_loop: while (i < arity) : (i += 1) {
                    try s.nextToken();
                    try parameters.append(try expr(s));
                    if (s.tokenType != .Sep)
                        break :arity_loop;
                }

                if (s.tokenType != .Close) {
                    log("expected a closing paren for function {}", f);
                    return error.InvalidFunctionArgs;
                }
                if (i != arity - 1) {
                    log("got {} params for function {} with arity {}", i, f, arity);
                    return error.WrongNumberOfFunctionArgs;
                }
            }

            try s.nextToken();

            const heapSlice = try std.mem.dupe(s.allocator, *Expr, parameters.toSlice());
            return s.createFuncWithSlice(f.fnPtr(), heapSlice);
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
            //warn("not implemented: tokenType {}\n", s.tokenType);
            return error.ParseError;
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
                ret.deinit(s.allocator);
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

fn expr_add_sub(s: *State) EvalError!*Expr {
    var ret = try term(s);

    while (s.tokenType == .Infix and (if (s.function) |f| f.eq(add) or f.eq(sub) else false)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.createFunc(f, ret, try term(s));
    }

    return ret;
}

fn exprBitwise(s: *State) EvalError!*Expr {
    var ret = try expr_add_sub(s);

    while (s.tokenType == .Infix and isBitwiseOp(s.function)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.createFunc(f, ret, try expr(s));
    }

    return ret;
}

fn isBitwiseOp(function: ?*const FuncCall) bool {
    return if (function) |f|
        f.eq(bitwise_xor) or f.eq(bitwise_and) or f.eq(bitwise_or)
    else
        false;
}

fn isShiftOp(function: ?*const FuncCall) bool {
    return if (function) |f|
        f.eq(shift_left) or f.eq(shift_right)
    else
        false;
}

fn expr(s: *State) EvalError!*Expr {
    if (s.tokenType == .Call and s.peekNextToken() == .InfixFunctionApply) {
        // abs $ -1 becomes abs(-1)
        const f = s.function.?.fnPtr();

        try s.nextToken();
        if (s.tokenType != .InfixFunctionApply)
            @panic("expected .InfixFunctionApply");
        try s.nextToken();

        return try s.createFunc(f, try list(s));
    }

    var ret = try exprBitwise(s);

    while (s.tokenType == .Infix and isShiftOp(s.function)) {
        const f = s.function.?.fnPtr();
        try s.nextToken();
        ret = try s.createFunc(f, ret, try expr(s));
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
    const root = list(&s) catch |e| {
        var spaces_buf = try std.Buffer.init(s.allocator, "");
        defer spaces_buf.deinit();
        var i: u16 = 0;
        while (i < s.currentCharIndex()) : (i += 1) try spaces_buf.append(" ");

        log("{}\n{}^", expression, spaces_buf.toSlice());
        return e;
    };
    if (s.tokenType != .End) {
        warn("not implemented: not at the end, s.tokenType is {}\n", s.tokenType);
        unreachable;
    }

    return root;
}

pub fn interp(allocator: *std.mem.Allocator, expr_str: []const u8, variables: []const Variable) !f64 {
    if (expr_str.len == 0)
        return error.EmptyExpression;

    const expression = try compile(allocator, expr_str, variables);
    defer expression.deinit(allocator);

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

const REINTERP = false;

fn shift_left(a: f64, amount: f64) f64 {
    return @intToFloat(f64, @floatToInt(u64, a) << @floatToInt(u6, a));
}

fn shift_right(a: f64, amount: f64) f64 {
    return @intToFloat(f64, @floatToInt(u64, a) >> @floatToInt(u6, a));
}

fn bitwise_xor(a: f64, b: f64) f64 {
    return if (REINTERP)
        @ptrCast(f64, @ptrCast(u64, a) ^ @ptrCast(u64, b))
    else
        @intToFloat(f64, @floatToInt(i64, a) ^ @floatToInt(i64, b));
}

fn bitwise_or(a: f64, b: f64) f64 {
    return if (REINTERP)
        @ptrCast(f64, @ptrCast(u64, a) | @ptrCast(u64, b))
    else
        @intToFloat(f64, @floatToInt(i64, a) | @floatToInt(i64, b));
}

fn bitwise_and(a: f64, b: f64) f64 {
    return if (REINTERP)
        @ptrCast(f64, @ptrCast(u64, a) & @ptrCast(u64, b))
    else
        @intToFloat(f64, @floatToInt(i64, a) & @floatToInt(i64, b));
}

fn bitwise_not(a: f64) f64 {
    return if (REINTERP)
        @ptrCast(f64, ~@ptrCast(u64, a))
    else
        @intToFloat(f64, ~@floatToInt(i64, a));
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

fn fract(a: f64) f64 {
    return a - std.math.floor(a);
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
    FuncCall.init("fract", fract),

    FuncCall.init("bitwise_xor", bitwise_xor),
    FuncCall.init("bitwise_and", bitwise_and),
    FuncCall.init("bitwise_or", bitwise_or),
    FuncCall.init("bitwise_not", bitwise_not),

    FuncCall.init("shift_left", shift_left),
    FuncCall.init("shift_right", shift_right),
};

fn assertInterp(expr_str: []const u8, expected_result: f64) !void {
    return assertInterpVars(expr_str, expected_result, [_]Variable{});
}

fn _testInterp(expr_str: []const u8, variables: []const Variable) EvalError!f64 {
    var bytes: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(bytes[0..]);
    const allocator = &fba.allocator;
    const result = try interp(allocator, expr_str, variables);
    return result;
}

fn assertInterpVars(expr_str: []const u8, expected_result: f64, variables: []const Variable) !void {
    const result = try _testInterp(expr_str, variables);
    if (result != expected_result) {
        warn("\nexpected {}, got {}\n", expected_result, result);
        warn("expression was: {}\n", expr_str);
        @panic("interpreted result does not match the expected string");
    }
}

test "infix operators" {
    try assertInterp("1", 1.0);
    try assertInterp("1+1", 2.0);
    try assertInterp("3-3", 0.0);
    try assertInterp("3*3", 9.0);
    try assertInterp("3*3*3", 27.0);
    try assertInterp("12/2", 6.0);
    try assertInterp("5/10", 0.5);
    try assertInterp("3^2", 1.0);
    try assertInterp("44^1", 45.0);
    try assertInterp("abs(1^2+3)", 4);
    try assertInterp("((1^2)+3)", 6);
    try assertInterp("12 % 5", 2);
    try assertInterp("12 % 4.5", 3);
    try assertInterp("abs(1)&0x1", 1);
    try assertInterp("1<<1", 2);
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
    try assertInterp("fract(5.5)", 0.5);
}

test "infix function application" {
    try assertInterp("abs $ -1", 1.0);
    std.testing.expectError(EvalError.ParseError, _testInterp("$ -1", [_]Variable{}));
}

test "negation" {
    try assertInterp("-1", -1.0);
    try assertInterp("-4*5", -20.0);
    try assertInterp("-1*-1", 1.0);
    try assertInterp("--1", 1.0);
    try assertInterp("--1", 1.0);
}

test "number literals" {
    try assertInterp("1", 1.0);
    try assertInterp("0x1", 1.0);
    try assertInterp("0x1", 1.0);
    try assertInterp("0x00ff00", 65280.0);
}

test "variables" {
    {
        var PI: f64 = std.math.pi;
        var x: f64 = 40;
        var y: f64 = 82;
        var time: f64 = 4;

        const testVarsArr = [_]Variable{
            Variable.init("PI", &PI),
            Variable.init("x", &x),
            Variable.init("y", &y),
            Variable.init("time", &time),
        };
        const testVars = testVarsArr[0..];
        try assertInterpVars("PI", 3.141592653589793, testVars);
        try assertInterpVars("fract(pow(x, y/time))*400.0", 0, testVars);
    }

    {
        var x: f64 = 0;
        var xPtr = &x;
        const vars = [_]Variable{Variable.init("x", xPtr)};

        while (x < 20) {
            x += 1.5;
            try assertInterpVars("x", x, vars);
        }
    }
}
