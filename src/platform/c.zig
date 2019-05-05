pub use @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("png.h");
    @cInclude("math.h");
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
});

const std = @import("std");
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;