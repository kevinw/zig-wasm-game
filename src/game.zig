usingnamespace @import("math3d.zig");

const std = @import("std");
const os = std.os;
const c = @import("platform.zig");
const panic = c.panic;
const bufPrint = std.fmt.bufPrint;
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const static_geometry = @import("static_geometry.zig");
const StaticGeometry = static_geometry.StaticGeometry;
const pieces = @import("pieces.zig");
const Piece = pieces.Piece;
const Spritesheet = @import("spritesheet.zig").Spritesheet;
const embedImage = @import("png.zig").embedImage;
const RawImage = @import("png.zig").RawImage;
const DebugConsole = @import("debug_console.zig").DebugConsole;

const gbe = @import("gbe");
const prefabs = @import("prefabs.zig");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");
const GameSession = @import("session.zig").GameSession;

const WHITE = vec4(1, 1, 1, 1);

pub var game_state: Game = undefined;

pub const Game = struct {
    window: *c.Window,
    session: GameSession,
    debug_console: DebugConsole,
    all_shaders: AllShaders,
    static_geometry: StaticGeometry,
    projection: Mat4x4,
    prng: std.rand.DefaultPrng,
    rand: *std.rand.Random,
    game_over: bool,
    font: Spritesheet,
    player: Spritesheet,
    player_sprite_index: u16,
    ghost_y: i32,
    framebuffer_width: c_int,
    framebuffer_height: c_int,
    level: i32,
    is_paused: bool,
    is_loading: bool,

    pub fn is_playing(self: Self) void {
        return !(self.is_paused || self.game_over || self.is_loading);
    }
};

const PI = 3.14159265358979;
const max_particle_count = 500;
const max_falling_block_count = grid_width * grid_height;
const margin_size = 10;
const grid_width = 10;
const grid_height = 20;
const cell_size = 32;
const board_width = grid_width * cell_size;
const board_height = grid_height * cell_size;
const board_left = margin_size;
const board_top = margin_size;

const next_piece_width = margin_size + 4 * cell_size + margin_size;
const next_piece_height = next_piece_width;
const next_piece_left = board_left + board_width + margin_size;
const next_piece_top = board_top + board_height - next_piece_height;

const score_width = next_piece_width;
const score_height = next_piece_height;
const score_left = next_piece_left;
const score_top = next_piece_top - margin_size - score_height;

const level_display_width = next_piece_width;
const level_display_height = next_piece_height;
const level_display_left = next_piece_left;
const level_display_top = score_top - margin_size - level_display_height;

const hold_piece_width = next_piece_width;
const hold_piece_height = next_piece_height;
const hold_piece_left = next_piece_left;
const hold_piece_top = level_display_top - margin_size - hold_piece_height;

pub const window_width = next_piece_left + next_piece_width + margin_size;
pub const window_height = board_top + board_height + margin_size;

const board_color = Vec4{ .data = [_]f32{ 72.0 / 255.0, 72.0 / 255.0, 72.0 / 255.0, 1.0 } };

const init_piece_delay = 0.5;
const min_piece_delay = 0.05;
const level_delay_increment = 0.05;

pub const font_char_width = 18;
pub const font_char_height = 32;

const gravity = 0.14;
const time_per_level = 60.0;

const AUDIO_BUFFER_SIZE = 2048;

const a: f32 = 0.1;

var beep = blk: {
    @setEvalBranchQuota(AUDIO_BUFFER_SIZE * 2 + 1);
    var b = [_]f32{0} ** AUDIO_BUFFER_SIZE;
    for (b) |*x, i| {
        x.* = if ((i / 64) % 2 == 1) a else -a;
    }
    break :blk b;
};

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

fn drawParticle(t: *Game, p: Particle) void {
    const model = mat4x4_identity.translateByVec(p.pos).rotate(p.angle, p.axis).scale(p.scale_w, p.scale_h, 0.0);

    const mvp = t.projection.mult(model);

    t.all_shaders.primitive.bind();
    t.all_shaders.primitive.setUniformVec4(t.all_shaders.primitive_uniform_color, p.color);
    t.all_shaders.primitive.setUniformMat4x4(t.all_shaders.primitive_uniform_mvp, mvp);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, t.static_geometry.triangle_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);

    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 3);
}

fn drawFallingBlock(t: *Game, p: Particle) void {
    const model = mat4x4_identity.translateByVec(p.pos).rotate(p.angle, p.axis).scale(p.scale_w, p.scale_h, 0.0);
    const mvp = t.projection.mult(model);
    fillRectMvp(t, p.color, mvp);
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
    const model = mat4x4_identity.translate(pos.data[0], pos.data[1], 0.0).scale(size, size, 0.0);
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
        //drawCenteredText(t, "play", 4.0, vec4(1, 1, 1, 0.5));
        const color = vec4(1, 1, 1, 1);

        var it = t.session.iter(Sprite);
        while (it.next()) |object| {
            if (!object.is_active) continue;
            const sprite = object.data;
            if (sprite.spritesheet) |spritesheet| {
                spritesheet.draw(t.all_shaders, sprite.index, sprite_matrix(t.projection, 48, sprite.pos), color);
            } else {
                fillRect(t, vec4(1, 0, 1, 1), sprite.pos.data[0], sprite.pos.data[1], 8, 8);
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

    Time.delta_time = @floatCast(f32, elapsed);
    Time.time += Time.delta_time;

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

pub fn restartGame(t: *Game) void {
    t.game_over = false;
    t.is_paused = false;
    t.debug_console.reset();

    t.session.init(42);

    const player_entity_id = prefabs.Player.spawn(&t.session, prefabs.Player.Params{}) catch unreachable;
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
