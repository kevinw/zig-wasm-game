pub const Destroy_Timer = @import("components/destroy_timer.zig").Destroy_Timer;
pub const Gun = @import("components/gun.zig").Gun;
pub const LiveShader = @import("components/liveshader.zig").LiveShader;
pub const Mojulo = @import("components/mojulo.zig").Mojulo;
pub const Mover = @import("components/mover.zig").Mover;
pub const Player = @import("components/player.zig").Player;
pub const Sprite = @import("components/sprite.zig").Sprite;
usingnamespace @import("session.zig");

const Destroy_Timer_SystemData = struct {
    id: EntityId,
    timer: *Destroy_Timer,
};

pub const run_Destroy_Timer = GameSession.buildSystem(Destroy_Timer_SystemData, Destroy_Timer_think);

inline fn Destroy_Timer_think(gs: *GameSession, self: Destroy_Timer_SystemData) bool {
    const mod = @import("components/destroy_timer.zig");
    return @inlineCall(mod.update, gs, self.timer);
}
        
usingnamespace @import("session.zig");

const Gun_SystemData = struct {
    id: EntityId,
    gun: *Gun,
    sprite: *Sprite,
};

pub const run_Gun = GameSession.buildSystem(Gun_SystemData, Gun_think);

inline fn Gun_think(gs: *GameSession, self: Gun_SystemData) bool {
    const mod = @import("components/gun.zig");
    return @inlineCall(mod.update, gs, self.gun, self.sprite);
}
        
usingnamespace @import("session.zig");

const LiveShader_SystemData = struct {
    id: EntityId,
    live_shader: *LiveShader,
};

pub const run_LiveShader = GameSession.buildSystem(LiveShader_SystemData, LiveShader_think);

inline fn LiveShader_think(gs: *GameSession, self: LiveShader_SystemData) bool {
    const mod = @import("components/liveshader.zig");
    return @inlineCall(mod.update, gs, self.live_shader);
}
        
usingnamespace @import("session.zig");

const Mojulo_SystemData = struct {
    id: EntityId,
    m: *Mojulo,
};

pub const run_Mojulo = GameSession.buildSystem(Mojulo_SystemData, Mojulo_think);

inline fn Mojulo_think(gs: *GameSession, self: Mojulo_SystemData) bool {
    const mod = @import("components/mojulo.zig");
    return @inlineCall(mod.update, gs, self.m);
}
        
usingnamespace @import("session.zig");

const Mover_SystemData = struct {
    id: EntityId,
    mover: *Mover,
    sprite: *Sprite,
};

pub const run_Mover = GameSession.buildSystem(Mover_SystemData, Mover_think);

inline fn Mover_think(gs: *GameSession, self: Mover_SystemData) bool {
    const mod = @import("components/mover.zig");
    return @inlineCall(mod.update, gs, self.mover, self.sprite);
}
        
usingnamespace @import("session.zig");

const Player_SystemData = struct {
    id: EntityId,
    player: *Player,
    sprite: *Sprite,
    gun: *Gun,
};

pub const run_Player = GameSession.buildSystem(Player_SystemData, Player_think);

inline fn Player_think(gs: *GameSession, self: Player_SystemData) bool {
    const mod = @import("components/player.zig");
    return @inlineCall(mod.update, gs, self.player, self.sprite, self.gun);
}
        
usingnamespace @import("session.zig");

const Sprite_SystemData = struct {
    id: EntityId,
    sprite: *Sprite,
};

pub const run_Sprite = GameSession.buildSystem(Sprite_SystemData, Sprite_think);

inline fn Sprite_think(gs: *GameSession, self: Sprite_SystemData) bool {
    const mod = @import("components/sprite.zig");
    return @inlineCall(mod.update, gs, self.sprite);
}
        
pub fn run_ALL(gs: *GameSession) void {
    run_Destroy_Timer(gs);
    run_Gun(gs);
    run_LiveShader(gs);
    run_Mojulo(gs);
    run_Mover(gs);
    run_Player(gs);
    run_Sprite(gs);
}
