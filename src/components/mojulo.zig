//capacity=20

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

        var uniforms = ShaderProgram.UniformList.init(c.allocator);
        new_shader.getUniforms(&uniforms);
    }
};

const game = @import("../game.zig");

fn worldToScreenPoint(world_position: Vec3, t: *game.Game) Vec3 {
    // calculate view-projection matrix
    const mat = t.projection.mult(t.view); 

    // multiply world point by VP matrix
    //Vector4 temp = mat * new Vector4(wp.x, wp.y, wp.z, 1f);
    var temp = mat.multVec4(vec4(world_position.x, world_position.y, world_position.z, 1));
    if (temp.w == 0) {
        // point is exactly on camera focus point, screen point is undefined
        // unity handles this by returning 0,0,0
        return Vec3.zero;
    } else {
        // convert x and y from clip space to window coordinates
        temp.x = (temp.x/temp.w + 1)*0.5 * @intToFloat(f32, t.framebuffer_width);
        temp.y = (temp.y/temp.w + 1)*0.5 * @intToFloat(f32, t.framebuffer_height);
        return vec3(temp.x, temp.y, world_position.z);
    }

}

pub fn update(gs: *GameSession, m: *Mojulo) bool {
    if (m.origin_transform) |xform| {
        if (m.shader) |*shader| {

            const t = &game.game_state;
            //const p = worldToScreenPoint(xform.position, t);
            const p = xform.position;

            shader.setUniform("playerPos", p);
            shader.setUniform("playerScale", 0.079);
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
