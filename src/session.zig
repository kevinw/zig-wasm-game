// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    Destroy_Timer: gbe.ComponentList(Destroy_Timer),
    Gun: gbe.ComponentList(Gun),
    LiveShader: gbe.ComponentList(LiveShader),
    Mojulo: gbe.ComponentList(Mojulo),
    Mover: gbe.ComponentList(Mover),
    Player: gbe.ComponentList(Player),
    Sprite: gbe.ComponentList(Sprite),
    Transform: gbe.ComponentList(Transform),
});
    