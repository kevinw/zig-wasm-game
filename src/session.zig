// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    AutoMover: gbe.ComponentList(AutoMover, 100),
    Destroy_Timer: gbe.ComponentList(Destroy_Timer, 100),
    Follow: gbe.ComponentList(Follow, 10),
    Gun: gbe.ComponentList(Gun, 10),
    LiveShader: gbe.ComponentList(LiveShader, 100),
    Maypole: gbe.ComponentList(Maypole, 10),
    Mojulo: gbe.ComponentList(Mojulo, 20),
    Mover: gbe.ComponentList(Mover, 100),
    Player: gbe.ComponentList(Player, 4),
    Renderer: gbe.ComponentList(Renderer, 100),
    Sprite: gbe.ComponentList(Sprite, 100),
    Transform: gbe.ComponentList(Transform, 100),
});
    