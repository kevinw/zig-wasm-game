usingnamespace @import("../globals.zig");

const RawImage = @import("../png.zig").RawImage;
const std = @import("std");
const c = @import("../platform.zig");
const ShaderProgram = @import("../all_shaders.zig").ShaderProgram;
const GameSession = @import("../session.zig").GameSession;
const Transform = @import("./transform.zig").Transform;
const open_sans_regular = @import("../opensansregular.zig");
const metrics = open_sans_regular;

const Vec2ArrayList = std.ArrayList(Vec2);

pub const SDFTextRenderer = struct {
    const Self = @This();

    shader: ?ShaderProgram = null,
    transform: ?*Transform = null,

    vertex_buffer: c.GLuint = 0,
    vertex_buffer_num_items: c_int = 0,

    texture_buffer: c.GLuint = 0,
    texture_buffer_num_items: c_int = 0,

    str: []const u8,

    texture: c.GLuint = 0,

    pub fn init(text: []const u8) Self {
        return SDFTextRenderer {
            .str=text,
        };
    }

    fn drawGlyph(self: *Self, chr: u32, pen: *Vec2, size: f32, vertex_elems: *Vec2ArrayList, texture_elems: *Vec2ArrayList) void {
        const metric = open_sans_regular.metrics(c.allocator).getValue(chr) orelse return;

        var scale = size / @intToFloat(f32, open_sans_regular.size);

        const factor = 1.0;
        var width = @intToFloat(f32, metric.values[0]);
        var height = @intToFloat(f32, metric.values[1]);
        var horiBearingX = @intToFloat(f32, metric.values[2]);
        var horiBearingY = @intToFloat(f32, metric.values[3]);
        var horiAdvance = @intToFloat(f32, metric.values[4]);
        var posX = @intToFloat(f32, metric.values[5]);
        var posY = @intToFloat(f32, metric.values[6]);

        if (width > 0 and height > 0) {
            width += open_sans_regular.buffer * 2;
            height += open_sans_regular.buffer * 2;

            const metrics_buffer = @intToFloat(f32, metrics.buffer);

            // Add a quad (= two triangles) per glyph.
            vertex_elems.append(vec2((factor * (pen.x + (horiBearingX - metrics_buffer * scale))), (factor * (pen.y - horiBearingY * scale)))) catch unreachable;
            vertex_elems.append(vec2((factor * (pen.x + ((horiBearingX - metrics_buffer + width) * scale))), (factor * (pen.y - horiBearingY * scale)))) catch unreachable;
            vertex_elems.append(vec2((factor * (pen.x + ((horiBearingX - metrics_buffer) * scale))), (factor * (pen.y + (height - horiBearingY) * scale)))) catch unreachable;

            vertex_elems.append(vec2((factor * (pen.x + ((horiBearingX - metrics_buffer + width) * scale))), (factor * (pen.y - horiBearingY * scale)))) catch unreachable;
            vertex_elems.append(vec2((factor * (pen.x + ((horiBearingX - metrics_buffer) * scale))), (factor * (pen.y + (height - horiBearingY) * scale)))) catch unreachable;
            vertex_elems.append(vec2((factor * (pen.x + ((horiBearingX - metrics_buffer + width) * scale))), (factor * (pen.y + (height - horiBearingY) * scale)))) catch unreachable;

            texture_elems.append(vec2(posX, posY)) catch unreachable;
            texture_elems.append(vec2(posX + width, posY)) catch unreachable;
            texture_elems.append(vec2(posX, posY + height)) catch unreachable;

            texture_elems.append(vec2(posX + width, posY)) catch unreachable;
            texture_elems.append(vec2(posX, posY + height)) catch unreachable;
            texture_elems.append(vec2(posX + width, posY + height)) catch unreachable;
        }

        // pen.x += Math.ceil(horiAdvance * scale);
        pen.x = pen.x + horiAdvance * scale;
    }

    fn measureText(text: []const u8, size: f32) f32 {
        var advance: f32 = 0;
        var scale = size / @intToFloat(f32, open_sans_regular.size);
        const s = std.unicode.Utf8View.init(text) catch unreachable;
        var it = s.iterator();
        var METRICS = open_sans_regular.metrics(c.allocator);
        while (it.nextCodepoint()) |codepoint| {
            if (METRICS.getValue(codepoint)) |v| {
                const horiAdvance = v.values[4];
                advance += @intToFloat(f32, horiAdvance) * scale;
            }
        }

        return advance;
    }

    fn initWithImage(self: *Self, raw_img: RawImage, w: c_int, h: c_int) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        const tex_type = if (c.is_web) c.GL_LUMINANCE else c.GL_RED;
        if (c.is_web) {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, tex_type, w, h, 0, tex_type, c.GL_UNSIGNED_BYTE, raw_img.raw.ptr, raw_img.pitch * raw_img.height);
        } else {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, tex_type, w, h, 0, tex_type, c.GL_UNSIGNED_BYTE, raw_img.raw.ptr);
        }
            
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

        if (self.shader) |*shader| {
            shader.setUniform("texsize", vec2(@intToFloat(f32, w), @intToFloat(f32, h)));
        }
    }

    fn createText(self: *Self, size: f32) void {
        var vertexElements = Vec2ArrayList.init(c.allocator);
        var textureElements = Vec2ArrayList.init(c.allocator);

        var advance = measureText(self.str, size);

        const midX = 400.0; // TODO
        const midY = 400.0;

        var pen = vec2(midX - advance / 2.0, midY / 2.0);

        var s = std.unicode.Utf8View.init(self.str) catch unreachable;
        var it = s.iterator();
        while (it.nextCodepoint()) |codepoint| {
            self.drawGlyph(codepoint, &pen, size, &vertexElements, &textureElements);
        }

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vertex_buffer);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(c.GLfloat), @ptrCast(*f32, vertexElements.toSlice().ptr), c.GL_STATIC_DRAW);
        self.vertex_buffer_num_items = @intCast(c_int, vertexElements.count() / 2);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.texture_buffer);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(c.GLfloat), @ptrCast(*f32, textureElements.toSlice().ptr), c.GL_STATIC_DRAW);
        self.texture_buffer_num_items = @intCast(c_int, textureElements.count() / 2);
    }

    pub fn draw(self: *Self) void {
        if (self.shader) |*shader| {
        } else {
            const ASSETS = "../../assets/";
            const vert = @embedFile(ASSETS ++ "sdf_text_vert.glsl");
            const frag = @embedFile(ASSETS ++ "sdf_text_frag.glsl");
            self.shader = ShaderProgram.create(vert, frag, null);

            self.texture = c.glCreateTexture();
            log("created texture {}", self.texture);

            self.vertex_buffer = c.glCreateBuffer();
            self.texture_buffer = c.glCreateBuffer();
            self.str = "hello world!";

            log("created shader");
        }

        if (self.shader) |*shader| {
            shader.bind();

            c.glEnableVertexAttribArray(@intCast(c.GLuint, shader.attribLoc("a_pos")));
            c.glEnableVertexAttribArray(@intCast(c.GLuint, shader.attribLoc("a_texcoord")));

            const w = 1000; // TODO
            const h = 500;

            var pMatrix = mat4x4Ortho(0, w, h, 0);

            const scale = 26.0;
            const buffer = 0.2;
            const angle = 0;
            const translateX = 0;
            const gamma = 1.0;
            const debug = 0;

            self.createText(scale);

            var mvMatrix = Mat4x4.identity
                .translate(w / 2, h / 2, 0)
                .rotate(angle, vec3(0, 0, 1))
                .translate(- w / 2, - h / 2, 0)
                .translate(translateX, 0, 0);

            var mvpMatrix = pMatrix.mult(mvMatrix);

            shader.setUniform("matrix", mvpMatrix);

            c.glActiveTexture(c.GL_TEXTURE0);
            c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
            shader.setUniformInt(shader.uniformLoc("u_texture"), 0);
            //c.glUniform1i(shader.u_texture, 0);

            shader.setUniform("scale", 1.0);
            //c.glUniform1f(shader.u_scale, 1.0);
            shader.setUniformFloatByName("debug", if (debug != 0) 1 else 0);
            //c.glUniform1f(shader.u_debug, ) 1 else 0);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vertex_buffer);
            c.glVertexAttribPointer(@intCast(c.GLuint, shader.attribLoc("a_pos")), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.texture_buffer);
            c.glVertexAttribPointer(@intCast(c.GLuint, shader.attribLoc("a_texcoord")), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

            //c.glUniform4fv(shader.u_color, [ 1, 1, 1, 1 ]);
            shader.setUniform("color", vec4(1, 1, 1, 1));
            //c.glUniform1f(shader.u_buffer, buffer);
            shader.setUniform("buffer", buffer);
            c.glDrawArrays(c.GL_TRIANGLES, 0, self.vertex_buffer_num_items);

            //c.glUniform4fv(shader.u_color, [ 0, 0, 0, 1 ]);
            shader.setUniform("color", vec4(0, 0, 0, 1));
            shader.setUniform("buffer", @floatCast(f32, 192.0 / 256.0));
            shader.setUniform("gamma", @floatCast(f32, gamma * 1.4142 / scale));
            c.glDrawArrays(c.GL_TRIANGLES, 0, self.vertex_buffer_num_items);

        }
    }
};

pub fn update(gs: *GameSession, self: *SDFTextRenderer) bool {
    return true;
}

test "metrics" {
    const testing = std.testing;

    var bytes: [50 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(bytes[0..]);
    const allocator = &fba.allocator;

    const foo = allocator.alloc(u32, 50);

    const metrics = open_sans_regular.metrics(allocator);
    testing.expectEqual(open_sans_regular.family, "Open Sans");
}
