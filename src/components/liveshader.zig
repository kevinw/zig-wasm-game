usingnamespace @import("../globals.zig");
const GameSession = @import("../session.zig").GameSession;

pub const LiveShader = struct {};

pub fn update(gs: *GameSession, live_shader: *LiveShader) bool {
    return true;
}
