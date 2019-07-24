// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    AutoMover: gbe.ComponentList(AutoMover),
    Destroy_Timer: gbe.ComponentList(Destroy_Timer),
    Gun: gbe.ComponentList(Gun),
    LiveShader: gbe.ComponentList(LiveShader),
    Mojulo: gbe.ComponentList(Mojulo),
    Mover: gbe.ComponentList(Mover),
    Player: gbe.ComponentList(Player),
    Renderer: gbe.ComponentList(Renderer),
    Sprite: gbe.ComponentList(Sprite),
    Transform: gbe.ComponentList(Transform),
});
    