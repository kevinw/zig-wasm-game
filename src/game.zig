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
const embedImage = @import("png.zig").elogmbedImage;
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
    const Self = @This();

    window: *c.Window,
    session: GameSession,
    debug_console: DebugConsole,
    all_shaders: AllShaders,
    static_geometry: static_geometry.StaticGeometry,
    //test_shader: ShaderProgram,

    projection: Mat4x4,
    view: Mat4x4,

    prng: std.rand.DefaultPrng,
    rand: *std.rand.Random,
    game_over: bool,
    font: Spritesheet,
    player_sprite: *Sprite,
    player: Spritesheet,
    bullet_sprite: Spritesheet,
    ghost_y: i32,
    framebuffer_width: c_int,
    framebuffer_height: c_int,
    level: i32,
    is_paused: bool,
    is_loading: bool,
    mojulo: ?*Mojulo,
    quit_requested: bool = false,

    equation_index: i32 = 0,

    pub fn is_playing(self: *Self) void {
        return !(self.is_paused || self.game_over || self.is_loading);
    }

    pub fn load_resources(self: *Self) void {
        const fetch = @import("fetch.zig");
        fetch.fromCellSize("assets/rocket.png", &self.player, 16, 16) catch unreachable;
        fetch.fromCellSize("assets/bullet.png", &self.bullet_sprite, 10, 10) catch unreachable;
    }

    pub fn cycleEquation(self: *Self, delta: i32) void {
        self.equation_index = std.math.mod(i32, self.equation_index + delta, equations.len) catch unreachable;
        setEquation(self);
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

const equations = [_][]const u8{
    "fract(pow(x, y/time))*400.0",
    "(x-time)*pow(x, 0.001*x*y)",
    "(((((sin(A * 20 + time/14) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/41) * 5) + time/22) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*0x0000ff)&0x00ff00) + (((((sin(A * 20 + time/7) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/83) * 5) + time/11) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*1)&0x0000ff) + (((((sin(A * 20 + time/3.5) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/166) * 5) + time/6) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*0x00ff00)&0xff0000)",
    "10  + 165 * sin(2.5+ (y-50) / 26 ) + 90*sin( time*0.7 - ((0.1*( x - 50 )^2 + (y-50)^2 )^0.45) ) - 255 * (1 + (((x-1) % 50) - (x % 50))) * (1 + (( (y+30-(time%18)-1) % 10) - ( (y+30-(time%18)) % 10))) * ((y%50) + (50-y)%50)",
    "((time-x+y)|(time-y+x)|(time+x+y)|(time-x-y))^6", // TODO: why is this one so different? https://maxbittker.github.io/Mojulo/#KCh0aW1lLXgreSl8KHRpbWUteSt4KXwodGltZSt4K3kpfCh0aW1lLXgteSkpXjY=
    "(y*x-(time*1))&(y+(cos(r*0.01*time)))",
    "r*A*r*pow(sin(0.001*time)+(cos(0.01*time)+1),A)",
    "cos(A*(r^x*4)*(sin(time*.01)+90))*(10000+pow(3,sin(time/15)))",
    "pow(r,2+cos(time*0.001))^((0.5*time)|(x*(sin(time*0.001)*10)))",
    "-time^(time*.5)&(time*.3) -1000*(x^(time*.1))&100*(y^(time*.15))",
    "(x*(time*sin(x*(time/900))*.1))-(y*(time*cos(y*time/1000)*.01))",
    "((y*5-time*cos(x))^(x*5-time*cos(y)))^-(sin(time*.01)/tan(x)*cos(r)*y)",
};

fn fillRectShader(s: *ShaderProgram, t: *Game, x: f32, y: f32, w: f32, h: f32) void {
    s.bind();

    const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
    s.setUniformMat4x4ByName("MVP", t.projection.mult(t.view.mult(model)));
    s.setUniformFloatByName("time", Time.frame_count);

    var gs = t.session;
    if (gs.findFirstObject(Player)) |player| {
        if (gs.find(player.entity_id, Sprite)) |playerSprite| {
            //s.setUniformVec3(s.uniformLoc("camPos"), playerSprite.pos.scale(0.3));
        }
    }

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
    const mvp = t.projection.mult(t.view.mult(model));
    fillRectMvp(t, color, mvp);
}

fn drawCenteredText(t: *Game, text: []const u8, scale: f32, color: Vec4) void {
    const len = @intToFloat(f32, text.len) * scale;
    const label_width = font_char_width * @floatToInt(i32, len);
    const draw_left = board_left + board_width / 2 - @divExact(label_width, 2);
    const draw_top = board_top + board_height / 2 - font_char_height / 2;
    drawTextWithColor(t, text, draw_left, draw_top, scale, color);
}

fn sprite_matrix(proj: Mat4x4, view: Mat4x4, pos: Vec3, size: f32) Mat4x4 {
    const model = mat4x4_identity.translate(pos.x, pos.y, 0.0).scale(size, size, 0.0);
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
        //fillRectShader(&t.test_shader, t, 0, 0, w, h);
        //fillRectShader(&t.mojulo.shader, t, 0, 0, w, h);
        //drawCenteredText(t, "play", 4.0, vec4(1, 1, 1, 0.5));
        const color = vec4(1, 1, 1, 1);

        // draw mojulos
        {
            var it = t.session.iter(Mojulo);
            while (it.next()) |object| {
                if (!object.is_active) continue;
                var mojulo = object.data;
                if (mojulo.shader) |*shader| {
                    if (t.session.find(object.entity_id, Transform)) |xform| {
                        const p = xform.position;
                        fillRectShader(shader, t, p.x, p.y, w, h);
                    }
                }
            }
        }

        {
            var it = t.session.iter(Sprite);
            while (it.next()) |object| {
                if (!object.is_active) continue;
                const sprite = object.data;
                if (sprite.spritesheet) |spritesheet| {
                    spritesheet.draw(t.all_shaders, sprite.index, sprite_matrix(t.projection, t.view, sprite.pos, 4.0), color);
                } else {
                    fillRect(t, vec4(1, 0, 1, 1), sprite.pos.x, sprite.pos.y, 16, 16);
                }
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
        if (col > '~') unreachable;
        const char_left = @intToFloat(f32, left) + @intToFloat(f32, i * font_char_width) * size;
        const model = mat4x4_identity.translate(char_left, @intToFloat(f32, top), 0.0).scale(size, size, 0.0);
        const mvp = t.projection.mult(t.view.mult(model));
        t.font.draw(t.all_shaders, col, mvp, color);
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

    const offset = t.player_sprite.pos.multScalar(-1).add(vec3(@intToFloat(f32, t.framebuffer_width) * 0.5, @intToFloat(f32, t.framebuffer_height) * 0.5, 0));
    t.view = mat4x4_identity.translateByVec(offset);
    t.debug_console.update(elapsed);
    t.session.applyRemovals();

    if (Input.getKey(c.KEY_Q)) {
        t.quit_requested = true;
    }
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

var equation_text: []const u8 = "fract(pow(x, y/time))*400.0";

comptime {
    _ = @import("tinyexpr.zig");
}

pub fn update_equation(t: *Game, eq_text: []const u8) void {
    update_equation_text(eq_text);
    restartGame(t);
}

pub fn update_equation_text(eq_text: []const u8) void {
    var buf = std.Buffer.init(c.allocator, "") catch unreachable;
    defer buf.deinit();
    @import("tinyglsl.zig").translate(&buf, eq_text) catch |e| {
        warn("{}", e);
        const s = std.fmt.allocPrint(c.allocator, "{{\"error\": true, \"reason\": \"{}\"}}", e) catch unreachable;
        defer c.allocator.free(s);
        comptime if (@hasField(c, "onEquationResultJSON")) // TODO: no
            c.onEquationResultJSON(s.ptr, s.len);
        return;
    };

    const glsl = buf.toSliceConst();
    //log("translated:      {}", glsl);

    equation_text = std.mem.concat(c.allocator, u8, [_][]const u8{ "return (", glsl, "); }" }) catch unreachable;
    //log("  set equation_text = {}", equation_text);
}

pub fn init(t: *Game) void {
    resetProjection(t);
    restartGame(t);
}

const ASSETS = "../assets/";
const vert = @embedFile(ASSETS ++ "mojulo_vert.glsl");
const fragTemplate = @embedFile(ASSETS ++ "mojulo_frag.glsl");

pub fn setEquation(t: *Game) void {
    const eq = equations[@intCast(usize, t.equation_index)];

    //update_equation_text(eq);
    //const frag = std.mem.concat(c.allocator, u8, [_][]const u8{ fragTemplate, equation_text }) catch unreachable;

    //t.test_shader.destroy();
    //t.test_shader = ShaderProgram.create(vert, frag, null);

    t.mojulo.?.setEquation(eq) catch unreachable;
}

pub fn restartGame(t: *Game) void {
    t.game_over = false;
    t.is_paused = false;
    t.debug_console.reset();
    const gs = &t.session;
    gs.init(42, c.allocator);

    const player_id = prefabs.Player.spawn(gs, prefabs.Player.Params{}) catch unreachable;
    if (gs.find(player_id, Sprite)) |player_sprite| {
        t.player_sprite = player_sprite;
    }

    const mojulo_id = prefabs.Mojulo.spawn(gs, vec3(0, 0, 0)) catch unreachable;
    if (gs.find(mojulo_id, Mojulo)) |mojulo| {
        log("created mojulo {}", mojulo_id);
        t.mojulo = mojulo;
        mojulo.setEquation("x*y*time") catch unreachable;
    }

    const mojulo_id_2 = prefabs.Mojulo.spawn(gs, vec3(-@intToFloat(f32, t.framebuffer_width), 80, 0)) catch unreachable;
    if (gs.find(mojulo_id_2, Mojulo)) |mojulo| {
        log("created mojulo {}", mojulo_id_2);
        mojulo.setEquation("x") catch unreachable;
    }

    setEquation(t);

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

    t.view = mat4x4_identity;
}
