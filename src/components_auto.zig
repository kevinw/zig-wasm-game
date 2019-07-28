pub const AutoMover = @import("components/automover.zig").AutoMover;
pub const Destroy_Timer = @import("components/destroy_timer.zig").Destroy_Timer;
pub const Follow = @import("components/follow.zig").Follow;
pub const Gun = @import("components/gun.zig").Gun;
pub const LiveShader = @import("components/liveshader.zig").LiveShader;
pub const Maypole = @import("components/maypole.zig").Maypole;
pub const Mojulo = @import("components/mojulo.zig").Mojulo;
pub const Mover = @import("components/mover.zig").Mover;
pub const Player = @import("components/player.zig").Player;
pub const Renderer = @import("components/renderer.zig").Renderer;
pub const Sprite = @import("components/sprite.zig").Sprite;
pub const Transform = @import("components/transform.zig").Transform;
usingnamespace @import("session.zig");

const AutoMover_SystemData = struct {
    id: EntityId,
    auto_mover: *AutoMover,
    transform: *Transform,
};

pub const run_AutoMover = GameSession.buildSystem(AutoMover_SystemData, AutoMover_think);

inline fn AutoMover_think(gs: *GameSession, self: AutoMover_SystemData) bool {
    const mod = @import("components/automover.zig");
    return @inlineCall(mod.update, gs, self.auto_mover, self.transform);
}
        
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

const Follow_SystemData = struct {
    id: EntityId,
    follow: *Follow,
};

pub const run_Follow = GameSession.buildSystem(Follow_SystemData, Follow_think);

inline fn Follow_think(gs: *GameSession, self: Follow_SystemData) bool {
    const mod = @import("components/follow.zig");
    return @inlineCall(mod.update, gs, self.follow);
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

const Maypole_SystemData = struct {
    id: EntityId,
    maypole: *Maypole,
};

pub const run_Maypole = GameSession.buildSystem(Maypole_SystemData, Maypole_think);

inline fn Maypole_think(gs: *GameSession, self: Maypole_SystemData) bool {
    const mod = @import("components/maypole.zig");
    return @inlineCall(mod.update, gs, self.maypole);
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

const Renderer_SystemData = struct {
    id: EntityId,
    renderer: *Renderer,
    transform: *Transform,
};

pub const run_Renderer = GameSession.buildSystem(Renderer_SystemData, Renderer_think);

inline fn Renderer_think(gs: *GameSession, self: Renderer_SystemData) bool {
    const mod = @import("components/renderer.zig");
    return @inlineCall(mod.update, gs, self.renderer, self.transform);
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
        
usingnamespace @import("session.zig");

const Transform_SystemData = struct {
    id: EntityId,
    transform: *Transform,
};

pub const run_Transform = GameSession.buildSystem(Transform_SystemData, Transform_think);

inline fn Transform_think(gs: *GameSession, self: Transform_SystemData) bool {
    const mod = @import("components/transform.zig");
    return @inlineCall(mod.update, gs, self.transform);
}
        
pub fn run_ALL(gs: *GameSession) void {
    run_AutoMover(gs);
    run_Destroy_Timer(gs);
    run_Follow(gs);
    run_Gun(gs);
    run_LiveShader(gs);
    run_Maypole(gs);
    run_Mojulo(gs);
    run_Mover(gs);
    run_Player(gs);
    run_Renderer(gs);
    run_Sprite(gs);
    run_Transform(gs);
}
