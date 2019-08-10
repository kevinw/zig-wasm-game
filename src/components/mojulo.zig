//capacity=100

const std = @import("std");
const c = @import("../platform.zig");
usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("./transform.zig").Transform;
const ShaderProgram = @import("../all_shaders.zig").ShaderProgram;
const tinyglsl = @import("../tinyglsl.zig");

const ASSETS = "../../assets/";
const vert = @embedFile(ASSETS ++ "mojulo_vert.glsl");
const fragTemplate = @embedFile(ASSETS ++ "mojulo_frag.glsl");

pub const Mojulo = struct {
    const Self = @This();

    shader: ?ShaderProgram = null,
    origin_transform: ?*Transform = null,

    fn setEquation(self: *Self, equation: []const u8) !void {
        const frag = try allocTranslateEquationToFragShader(equation);
        defer c.allocator.free(frag);

        if (self.shader) |*shader| shader.destroy();
        const new_shader = ShaderProgram.create(vert, frag, null);
        self.shader = new_shader;
    }
};

const game = @import("../game.zig");

pub fn update(gs: *GameSession, m: *Mojulo) bool {
    if (m.origin_transform) |xform| {
        if (m.shader) |*shader| {

            const t = &game.game_state;
            const p = xform.position;

            shader.setUniform("playerPos", p);

            //shader.setUniform("playerScale", 0.079);
            shader.setUniform("playerScale", 1.000);
        }
    }

    return true;
}

fn allocTranslateEquationToFragShader(equation: []const u8) ![]const u8 {
    var buf = try std.Buffer.init(c.allocator, "");
    defer buf.deinit();

    try tinyglsl.translate(&buf, equation);

    return try std.mem.concat(c.allocator, u8, [_][]const u8{
        fragTemplate,
        "return (",
        buf.toSliceConst(),
        "); }",
    });
}
