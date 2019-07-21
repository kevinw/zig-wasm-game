pub usingnamespace @import("native.zig");
usingnamespace @import("native.zig");

const std = @import("std");
pub const allocator = std.heap.c_allocator;
pub const panic = std.debug.panic;
pub const warn = std.debug.warn;
pub const Window = c_void; //@typeOf(glfwCreateWindow(game.window_width, game.window_height, c"WasmGame", null, null));

pub const KEY_RIGHT = GLFW_KEY_RIGHT;
pub const KEY_LEFT = GLFW_KEY_LEFT;
pub const KEY_UP = GLFW_KEY_UP;
pub const KEY_DOWN = GLFW_KEY_DOWN;

pub const KEY_D = GLFW_KEY_D;
pub const KEY_J = GLFW_KEY_J;
pub const KEY_K = GLFW_KEY_K;
pub const KEY_W = GLFW_KEY_W;
pub const KEY_A = GLFW_KEY_A;
pub const KEY_S = GLFW_KEY_S;
pub const KEY_L = GLFW_KEY_L;
pub const KEY_I = GLFW_KEY_I;
