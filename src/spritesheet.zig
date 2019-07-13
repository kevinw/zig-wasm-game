const c = @import("platform.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
usingnamespace @import("math3d.zig");
const allocator = c.allocator;
const RawImage = @import("png.zig").RawImage;

pub const Spritesheet = struct {
    img: RawImage,
    count: usize,
    texture_id: c.GLuint,
    vertex_buffer: c.GLuint,
    tex_coord_buffers: []c.GLuint,
    did_init: bool,

    pub fn draw(s: *const Spritesheet, as: AllShaders, index: usize, mvp: Mat4x4, color: Vec4) void {
        if (!s.did_init) return;

        as.texture.bind();
        as.texture.setUniformMat4x4(as.texture_uniform_mvp, mvp);
        as.texture.setUniformInt(as.texture_uniform_tex, 0);
        as.texture.setUniformVec4(as.texture_uniform_tint, color);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.vertex_buffer);
        c.glEnableVertexAttribArray(@intCast(c.GLuint, as.texture_attrib_position));
        c.glVertexAttribPointer(@intCast(c.GLuint, as.texture_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.tex_coord_buffers[index]);
        c.glEnableVertexAttribArray(@intCast(c.GLuint, as.texture_attrib_tex_coord));
        c.glVertexAttribPointer(@intCast(c.GLuint, as.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, if (c.is_web) 0 else null);

        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, s.texture_id);

        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }

    pub fn init(s: *Spritesheet, raw_img: RawImage, w: usize, h: usize) !void {
        s.img = raw_img;
        const col_count = s.img.width / w;
        const row_count = s.img.height / h;
        if (col_count == 0) @panic("col_count cannot be zero");
        if (row_count == 0) @panic("row_count cannot be zero");
        s.count = col_count * row_count;

        c.glGenTextures(1, &s.texture_id);
        errdefer c.glDeleteTextures(1, &s.texture_id);

        c.glBindTexture(c.GL_TEXTURE_2D, s.texture_id);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glPixelStorei(c.GL_PACK_ALIGNMENT, 4);
        if (c.is_web) {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(c_int, s.img.width), @intCast(c_int, s.img.height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, s.img.raw.ptr, s.img.pitch * s.img.height);
        } else {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(c_int, s.img.width), @intCast(c_int, s.img.height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, s.img.raw.ptr);
        }

        c.glGenBuffers(1, &s.vertex_buffer);
        errdefer c.glDeleteBuffers(1, &s.vertex_buffer);

        const vertexes = [_][3]c.GLfloat{
            [_]c.GLfloat{ 0.0, 0.0, 0.0 },
            [_]c.GLfloat{ 0.0, @intToFloat(c.GLfloat, h), 0.0 },
            [_]c.GLfloat{ @intToFloat(c.GLfloat, w), 0.0, 0.0 },
            [_]c.GLfloat{ @intToFloat(c.GLfloat, w), @intToFloat(c.GLfloat, h), 0.0 },
        };

        c.glBindBuffer(c.GL_ARRAY_BUFFER, s.vertex_buffer);
        c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 3 * @sizeOf(c.GLfloat), &vertexes[0][0], c.GL_STATIC_DRAW);

        s.tex_coord_buffers = allocator.alloc(c.GLuint, s.count) catch return error.NoMem;
        errdefer allocator.free(s.tex_coord_buffers);

        c.glGenBuffers(@intCast(c_int, s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);
        errdefer c.glDeleteBuffers(@intCast(c.GLint, s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);

        for (s.tex_coord_buffers) |tex_coord_buffer, i| {
            const upside_down_row = i / col_count;
            const col = i % col_count;
            const row = row_count - upside_down_row - 1;

            const x = @intToFloat(f32, col * w);
            const y = @intToFloat(f32, row * h);

            const img_w = @intToFloat(f32, s.img.width);
            const img_h = @intToFloat(f32, s.img.height);
            const tex_coords = [_][2]c.GLfloat{
                [_]c.GLfloat{
                    x / img_w,
                    (y + @intToFloat(f32, h)) / img_h,
                },
                [_]c.GLfloat{
                    x / img_w,
                    y / img_h,
                },
                [_]c.GLfloat{
                    (x + @intToFloat(f32, w)) / img_w,
                    (y + @intToFloat(f32, h)) / img_h,
                },
                [_]c.GLfloat{
                    (x + @intToFloat(f32, w)) / img_w,
                    y / img_h,
                },
            };

            c.glBindBuffer(c.GL_ARRAY_BUFFER, tex_coord_buffer);
            c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), &tex_coords[0][0], c.GL_STATIC_DRAW);
        }

        s.did_init = true;
    }

    pub fn deinit(s: *Spritesheet) void {
        c.glDeleteBuffers(@intCast(c_int, s.tex_coord_buffers.len), &s.tex_coord_buffers[0]);
        allocator.free(s.tex_coord_buffers);
        c.glDeleteBuffers(1, &s.vertex_buffer);
        c.glDeleteTextures(1, &s.texture_id);
    }
};
