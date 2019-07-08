usingnamespace @import("math3d.zig");

const std = @import("std");
const os = std.os;
const c = @import("platform.zig");
const panic = c.panic;
//const assert = std.debug.assert;
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
const SceneNode = @import("scenegraph.zig").SceneNode;

//const gbe = @import("../oxid/gbe.zig");
const gbe = @import("gbe");
const prefabs = @import("prefabs.zig");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");
const GameSession = @import("session.zig").GameSession;

const WHITE = vec4(1, 1, 1, 1);

fn updateSession(gs: *GameSession) void {
    @import("systems/player.zig").run(gs);
    @import("components/sprite.zig").run(gs);
}

pub const Tetris = struct {
    window: *c.Window,
    session: GameSession,
    debug_console: DebugConsole,
    all_shaders: AllShaders,
    static_geometry: StaticGeometry,
    projection: Mat4x4,
    prng: std.rand.DefaultPrng,
    rand: *std.rand.Random,
    piece_delay: f64,
    delay_left: f64,
    grid: [grid_height][grid_width]Cell,
    next_piece: *const Piece,
    hold_piece: ?*const Piece,
    hold_was_set: bool,
    cur_piece: *const Piece,
    cur_piece_x: i32,
    cur_piece_y: i32,
    cur_piece_rot: usize,
    score: c_int,
    game_over: bool,
    next_particle_index: usize,
    next_falling_block_index: usize,
    font: Spritesheet,
    player: Spritesheet,
    player_sprite_index: u16,
    ghost_y: i32,
    framebuffer_width: c_int,
    framebuffer_height: c_int,
    screen_shake_timeout: f64,
    screen_shake_elapsed: f64,
    level: i32,
    time_till_next_level: f64,
    piece_pool: [pieces.pieces.len]i32,
    is_paused: bool,
    is_loading: bool,

    pub fn is_playing(self: Self) void {
        return !(self.is_paused || self.game_over || self.is_loading);
    }

    particles: [max_particle_count]?Particle,
    falling_blocks: [max_falling_block_count]?Particle,
};

const Cell = union(enum) {
    Empty,
    Color: Vec4,
};

const Particle = struct {
    color: Vec4,
    pos: Vec3,
    vel: Vec3,
    axis: Vec3,
    scale_w: f32,
    scale_h: f32,
    angle: f32,
    angle_vel: f32,
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

const empty_row = [_]Cell{Cell{ .Empty = {} }} ** grid_width;
const empty_grid = [_][grid_width]Cell{empty_row} ** grid_height;

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

pub var tetris_state: Tetris = undefined;

fn fillRectMvp(t: *Tetris, color: Vec4, mvp: Mat4x4) void {
    t.all_shaders.primitive.bind();
    t.all_shaders.primitive.setUniformVec4(t.all_shaders.primitive_uniform_color, color);
    t.all_shaders.primitive.setUniformMat4x4(t.all_shaders.primitive_uniform_mvp, mvp);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, t.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, t.all_shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);

    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

fn fillRect(t: *Tetris, color: Vec4, x: f32, y: f32, w: f32, h: f32) void {
    const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
    const mvp = t.projection.mult(model);
    fillRectMvp(t, color, mvp);
}

fn drawParticle(t: *Tetris, p: Particle) void {
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

fn drawFallingBlock(t: *Tetris, p: Particle) void {
    const model = mat4x4_identity.translateByVec(p.pos).rotate(p.angle, p.axis).scale(p.scale_w, p.scale_h, 0.0);
    const mvp = t.projection.mult(model);
    fillRectMvp(t, p.color, mvp);
}

fn drawCenteredText(t: *Tetris, text: []const u8, scale: f32, color: Vec4) void {
    const len = @intToFloat(f32, text.len) * scale;
    const label_width = font_char_width * @floatToInt(i32, len);
    const draw_left = board_left + board_width / 2 - @divExact(label_width, 2);
    const draw_top = board_top + board_height / 2 - font_char_height / 2;
    drawTextWithColor(t, text, draw_left, draw_top, scale, color);
}

pub fn draw(t: *Tetris) void {
    if (t.is_loading) {
        drawCenteredText(t, "LOADING", 2.0, WHITE);
    } else if (t.game_over) {
        drawCenteredText(t, "GAME OVER", 1.0, WHITE);
    } else if (t.is_paused) {
        drawCenteredText(t, "PAUSED", 1.0, WHITE);
    } else {
        drawCenteredText(t, "play", 4.0, vec4(1, 1, 1, 0.5));

        {
            const player_maybe = t.session.findFirst(Player);
            if (player_maybe) |player| {
                const pos = &player.pos.data;

                const left = 0;
                const top = pos[1];
                const size = 1;
                const i = 0;
                const sprite_width = 48;
                const sprite_left = pos[0] + @intToFloat(f32, left) + @intToFloat(f32, i * sprite_width) * size;
                const model = mat4x4_identity.translate(sprite_left, top, 0.0).scale(size, size, 0.0);
                const view = mat4x4_identity.translate(0, 0, 0);
                const mvp = t.projection.mult(view).mult(model);
                const color = vec4(1, 1, 1, 1);
                t.player.draw(t.all_shaders, 0, mvp, color);
            }
        }
    }

    t.debug_console.draw(t);

    debug_gl.assertNoError();
}

fn drawOld(t: *Tetris) void {
    //fillRect(t, board_color, board_left, board_top, board_width, board_height);
    //fillRect(t, board_color, next_piece_left, next_piece_top, next_piece_width, next_piece_height);
    //fillRect(t, board_color, score_left, score_top, score_width, score_height);
    //fillRect(t, board_color, level_display_left, level_display_top, level_display_width, level_display_height);
    //fillRect(t, board_color, hold_piece_left, hold_piece_top, hold_piece_width, hold_piece_height);
    {
        const abs_x = board_left + t.cur_piece_x * cell_size;
        const abs_y = board_top + t.cur_piece_y * cell_size;
        drawPiece(t, t.cur_piece.*, abs_x, abs_y, t.cur_piece_rot);

        const ghost_color = vec4(t.cur_piece.color.data[0], t.cur_piece.color.data[1], t.cur_piece.color.data[2], 0.2);
        drawPieceWithColor(t, t.cur_piece.*, abs_x, t.ghost_y, t.cur_piece_rot, ghost_color);

        drawPiece(t, t.next_piece.*, next_piece_left + margin_size, next_piece_top + margin_size, 0);
        if (t.hold_piece) |piece| {
            if (!t.hold_was_set) {
                drawPiece(t, piece.*, hold_piece_left + margin_size, hold_piece_top + margin_size, 0);
            } else {
                const grey = vec4(0.65, 0.65, 0.65, 1.0);
                drawPieceWithColor(t, piece.*, hold_piece_left + margin_size, hold_piece_top + margin_size, 0, grey);
            }
        }

        for (t.grid) |row, y| {
            for (row) |cell, x| {
                switch (cell) {
                    Cell.Color => |color| {
                        const cell_left = board_left + @intCast(i32, x) * cell_size;
                        const cell_top = board_top + @intCast(i32, y) * cell_size;
                        fillRect(
                            t,
                            color,
                            @intToFloat(f32, cell_left),
                            @intToFloat(f32, cell_top),
                            cell_size,
                            cell_size,
                        );
                    },
                    else => {},
                }
            }
        }
    }

    {
        const score_text = "SCORE:";
        const score_label_width = font_char_width * @intCast(i32, score_text.len);
        drawText(
            t,
            score_text,
            score_left + score_width / 2 - score_label_width / 2,
            score_top + margin_size,
            1.0,
        );
    }
    {
        var score_text_buf: [20]u8 = undefined;
        const score_text = bufPrint(score_text_buf[0..], "{}", t.score) catch unreachable;
        const score_label_width = font_char_width * @intCast(i32, score_text.len);
        drawText(t, score_text, score_left + score_width / 2 - @divExact(score_label_width, 2), score_top + score_height / 2, 1.0);
    }
    {
        const text = "LEVEL:";
        const text_width = font_char_width * @intCast(i32, text.len);
        drawText(t, text, level_display_left + level_display_width / 2 - text_width / 2, level_display_top + margin_size, 1.0);
    }
    {
        var text_buf: [20]u8 = undefined;
        const text = bufPrint(text_buf[0..], "{}", t.level) catch unreachable;
        const text_width = font_char_width * @intCast(i32, text.len);
        drawText(t, text, level_display_left + level_display_width / 2 - @divExact(text_width, 2), level_display_top + level_display_height / 2, 1.0);
    }
    {
        const text = "HOLD:";
        const text_width = font_char_width * @intCast(i32, text.len);
        drawText(t, text, hold_piece_left + hold_piece_width / 2 - text_width / 2, hold_piece_top + margin_size, 1.0);
    }

    for (t.falling_blocks) |maybe_particle| {
        if (maybe_particle) |particle| {
            drawFallingBlock(t, particle);
        }
    }

    for (t.particles) |maybe_particle| {
        if (maybe_particle) |particle| {
            drawParticle(t, particle);
        }
    }
}

pub fn drawText(t: *const Tetris, text: []const u8, left: i32, top: i32, size: f32) void {
    drawTextWithColor(t, text, left, top, size, WHITE);
}

pub fn drawTextWithColor(t: *const Tetris, text: []const u8, left: i32, top: i32, size: f32, color: Vec4) void {
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

fn drawPiece(t: *Tetris, piece: Piece, left: i32, top: i32, rot: usize) void {
    drawPieceWithColor(t, piece, left, top, rot, piece.color);
}

fn drawPieceWithColor(t: *Tetris, piece: Piece, left: i32, top: i32, rot: usize, color: Vec4) void {
    for (piece.layout[rot]) |row, y| {
        for (row) |is_filled, x| {
            if (!is_filled) continue;
            const abs_x = @intToFloat(f32, left + @intCast(i32, x) * cell_size);
            const abs_y = @intToFloat(f32, top + @intCast(i32, y) * cell_size);

            fillRect(t, color, abs_x, abs_y, cell_size, cell_size);
        }
    }
}

pub fn nextFrame(t: *Tetris, elapsed: f64) void {
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

    if (t.is_paused) return;

    Time.delta_time = @floatCast(f32, elapsed);
    Time.time += Time.delta_time;

    updateSession(&t.session);

    t.debug_console.update(elapsed);
}

pub fn logMessage(t: *Tetris) void {
    t.debug_console.log("hello, world!");
}

pub fn userTogglePause(t: *Tetris) void {
    if (t.game_over) return;
    t.is_paused = !t.is_paused;
}

pub fn didImageLoad() void {
    tetris_state.is_loading = false;
}

pub fn restartGame(t: *Tetris) void {
    t.piece_delay = init_piece_delay;
    t.delay_left = init_piece_delay;
    t.score = 0;
    t.game_over = false;
    t.screen_shake_elapsed = 0.0;
    t.screen_shake_timeout = 0.0;
    t.level = 1;
    t.time_till_next_level = time_per_level;
    t.is_paused = false;
    t.hold_was_set = false;
    t.hold_piece = null;

    t.piece_pool = [_]i32{1} ** pieces.pieces.len;

    t.grid = empty_grid;

    t.debug_console.reset();

    const player_entity_id = prefabs.Player.spawn(&t.session, prefabs.Player.Params{});
}

pub fn resetProjection(t: *Tetris) void {
    t.projection = mat4x4Ortho(
        0.0,
        @intToFloat(f32, t.framebuffer_width),
        @intToFloat(f32, t.framebuffer_height),
        0.0,
    );
}
