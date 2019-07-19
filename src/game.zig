usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

const std = @import("std");
const warn = @import("base.zig").warn;
const os = std.os;
const c = @import("platform.zig");
const bufPrint = std.fmt.bufPrint;
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const static_geometry = @import("static_geometry.zig");
const pieces = @import("pieces.zig");
const Piece = pieces.Piece;
const Spritesheet = @import("spritesheet.zig").Spritesheet;
const embedImage = @import("png.zig").embedImage;
const RawImage = @import("png.zig").RawImage;
const DebugConsole = @import("debug_console.zig").DebugConsole;
const gbe = @import("gbe");
const prefabs = @import("prefabs.zig");
const GameSession = @import("session.zig").GameSession;
const ShaderProgram = @import("all_shaders.zig").ShaderProgram;
const tinyexpr = @import("tinyexpr.zig");

const WHITE = vec4(1, 1, 1, 1);

pub var game_state: Game = undefined;

pub const Game = struct {
    window: *c.Window,
    session: GameSession,
    debug_console: DebugConsole,
    all_shaders: AllShaders,
    static_geometry: static_geometry.StaticGeometry,
    test_shader: ShaderProgram,
    projection: Mat4x4,
    prng: std.rand.DefaultPrng,
    rand: *std.rand.Random,
    game_over: bool,
    font: Spritesheet,
    player: Spritesheet,
    bullet_sprite: Spritesheet,
    ghost_y: i32,
    framebuffer_width: c_int,
    framebuffer_height: c_int,
    level: i32,
    is_paused: bool,
    is_loading: bool,
    mojulo: Mojulo,

    pub fn is_playing(self: Self) void {
        return !(self.is_paused || self.game_over || self.is_loading);
    }
};

const margin_size = 10;
const grid_width = 10;
const grid_height = 20;
const cell_size = 32;
const board_width = grid_width * cell_size;
const board_height = grid_height * cell_size;
const board_left = margin_size;
const board_top = margin_size;
pub const font_char_width = 18;
pub const font_char_height = 32;

const a: f32 = 0.1;

fn fillRectShader(s: *ShaderProgram, t: *Game, x: f32, y: f32, w: f32, h: f32) void {
    s.bind();

    const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
    s.setUniformMat4x4(s.uniformLoc("MVP"), t.projection.mult(model));
    s.setUniformFloat(s.uniformLoc("time"), Time.frame_count);

    {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, t.static_geometry.rect_2d_vertex_buffer);
        const attribPos = s.attribLoc("VertexPosition");
        c.glEnableVertexAttribArray(@intCast(c.GLuint, attribPos));
        c.glVertexAttribPointer(@intCast(c.GLuint, attribPos), 3, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);
    }
    {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, t.static_geometry.rect_2d_tex_coord_buffer);
        const attribLoc = s.attribLoc("TexCoord");
        c.glEnableVertexAttribArray(@intCast(c.GLuint, attribLoc));
        c.glVertexAttribPointer(@intCast(c.GLuint, attribLoc), 2, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);
    }

    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

fn fillRectMvp(t: *Game, color: Vec4, mvp: Mat4x4) void {
    t.all_shaders.primitive.bind();
    t.all_shaders.primitive.setUniformVec4(t.all_shaders.primitive_uniform_color, color);
    t.all_shaders.primitive.setUniformMat4x4(t.all_shaders.primitive_uniform_mvp, mvp);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, t.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);
    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

fn fillRect(t: *Game, color: Vec4, x: f32, y: f32, w: f32, h: f32) void {
    const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
    const mvp = t.projection.mult(model);
    fillRectMvp(t, color, mvp);
}

fn drawCenteredText(t: *Game, text: []const u8, scale: f32, color: Vec4) void {
    const len = @intToFloat(f32, text.len) * scale;
    const label_width = font_char_width * @floatToInt(i32, len);
    const draw_left = board_left + board_width / 2 - @divExact(label_width, 2);
    const draw_top = board_top + board_height / 2 - font_char_height / 2;
    drawTextWithColor(t, text, draw_left, draw_top, scale, color);
}

fn sprite_matrix(proj: Mat4x4, sprite_width: i32, pos: Vec3) Mat4x4 {
    const size = 1;
    const model = mat4x4_identity.translate(pos.x, pos.y, 0.0).scale(size, size, 0.0);
    const view = mat4x4_identity.translate(0, 0, 0);
    const mvp = proj.mult(view).mult(model);
    return mvp;
}

pub fn draw(t: *Game) void {
    if (t.is_loading) {
        drawCenteredText(t, "LOADING", 2.0, WHITE);
    } else if (t.game_over) {
        drawCenteredText(t, "GAME OVER", 1.0, WHITE);
    } else if (t.is_paused) {
        drawCenteredText(t, "PAUSED", 1.0, WHITE);
    } else {
        const w = @intToFloat(f32, t.framebuffer_width);
        const h = @intToFloat(f32, t.framebuffer_height);
        fillRectShader(&t.test_shader, t, 0, 0, w, h);
        //drawCenteredText(t, "play", 4.0, vec4(1, 1, 1, 0.5));
        const color = vec4(1, 1, 1, 1);

        var it = t.session.iter(Sprite);
        while (it.next()) |object| {
            if (!object.is_active) continue;
            const sprite = object.data;
            if (sprite.spritesheet) |spritesheet| {
                spritesheet.draw(t.all_shaders, sprite.index, sprite_matrix(t.projection, 48, sprite.pos), color);
            } else {
                fillRect(t, vec4(1, 0, 1, 1), sprite.pos.x, sprite.pos.y, 8, 8);
            }
        }
    }

    t.debug_console.draw(t);

    debug_gl.assertNoError();
}

pub fn drawText(t: *const Game, text: []const u8, left: i32, top: i32, size: f32) void {
    drawTextWithColor(t, text, left, top, size, WHITE);
}

pub fn drawTextWithColor(t: *const Game, text: []const u8, left: i32, top: i32, size: f32, color: Vec4) void {
    for (text) |col, i| {
        if (col <= '~') {
            const char_left = @intToFloat(f32, left) + @intToFloat(f32, i * font_char_width) * size;
            const model = mat4x4_identity.translate(char_left, @intToFloat(f32, top), 0.0).scale(size, size, 0.0);
            const mvp = t.projection.mult(model);
            t.font.draw(t.all_shaders, col, mvp, color);
        } else {
            unreachable;
        }
    }
}

fn drawPiece(t: *Game, piece: Piece, left: i32, top: i32, rot: usize) void {
    drawPieceWithColor(t, piece, left, top, rot, piece.color);
}

fn drawPieceWithColor(t: *Game, piece: Piece, left: i32, top: i32, rot: usize, color: Vec4) void {
    for (piece.layout[rot]) |row, y| {
        for (row) |is_filled, x| {
            if (!is_filled) continue;
            const abs_x = @intToFloat(f32, left + @intCast(i32, x) * cell_size);
            const abs_y = @intToFloat(f32, top + @intCast(i32, y) * cell_size);

            fillRect(t, color, abs_x, abs_y, cell_size, cell_size);
        }
    }
}

pub fn nextFrame(t: *Game, elapsed: f64) void {
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

    if (t.is_paused) return;

    Time._update_next_frame(elapsed);

    @import("components_auto.zig").run_ALL(&t.session);
    t.debug_console.update(elapsed);
    t.session.applyRemovals();
}

pub fn logMessage(t: *Game) void {
    t.debug_console.log("hello, world!");
}

pub fn userTogglePause(t: *Game) void {
    if (t.game_over) return;
    t.is_paused = !t.is_paused;
}

pub fn didImageLoad() void {
    tetris_state.is_loading = false;
}

var equation_text: []const u8 = "return fract(pow(x, y/time))*400.0;\n}";

comptime {
    _ = @import("tinyexpr.zig");
}

pub fn update_equation(t: *Game, eq_text: []const u8) void {
    c.log("update equation: {}", eq_text);

    var buf = std.Buffer.init(c.allocator, "") catch unreachable;
    defer buf.deinit();
    @import("tinyglsl.zig").translate(&buf, eq_text) catch |e| {
        warn("{}", e);
        const s = std.fmt.allocPrint(c.allocator, "{{\"error\": true, \"reason\": \"{}\"}}", e) catch unreachable;
        defer c.allocator.free(s);
        c.onEquationResultJSON(s.ptr, s.len);
        return;
    };

    const glsl = buf.toSliceConst();
    c.log("translated:      {}", glsl);

    const slices = [_][]const u8{
        "return (", glsl, ");\n}",
    };

    equation_text = std.mem.concat(c.allocator, u8, slices) catch unreachable;
    restartGame(t);
}

pub fn restartGame(t: *Game) void {
    t.game_over = false;
    t.is_paused = false;
    t.debug_console.reset();

    const ASSETS = "../assets/";
    const vert = @embedFile(ASSETS ++ "mojulo_vert.glsl");
    const fragTemplate = @embedFile(ASSETS ++ "mojulo_frag.glsl");
    //const frag = std.fmt.allocPrint(c.allocator, fragTemplate) catch unreachable;
    //pub fn concat(allocator: *Allocator, comptime T: type, slices: []const []const T) ![]T {

    const slices = [_][]const u8{ fragTemplate, equation_text };
    const frag = std.mem.concat(c.allocator, u8, slices) catch unreachable;

    //const fragTemplate = @embedFile("../assets/mojulo_frag.glsl");

    //const frag = blk: {
    //    @setEvalBranchQuota(5000);
    //    const frag = std.fmt.allocPrint(c.allocator, fragTemplate) catch unreachable;
    //    defer c.allocator.free(frag);
    //    break :blk frag;
    //};

    t.test_shader = ShaderProgram.create(vert, frag, null);

    const gs = &t.session;
    gs.init(42, c.allocator);
    _ = prefabs.Player.spawn(gs, prefabs.Player.Params{}) catch unreachable;
    const mojulo_id = prefabs.Mojulo.spawn(gs, vec3(20, 80, 0));

    if (t.session.findFirst(Sprite)) |spr| {
        spr.spritesheet = &t.player;
    }
}

pub fn resetProjection(t: *Game) void {
    t.projection = mat4x4Ortho(
        0.0,
        @intToFloat(f32, t.framebuffer_width),
        @intToFloat(f32, t.framebuffer_height),
        0.0,
    );
}
