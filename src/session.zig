// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    Destroy_Timer: gbe.ComponentList(Destroy_Timer, 100),
    Gun: gbe.ComponentList(Gun, 100),
    Mover: gbe.ComponentList(Mover, 100),
    Player: gbe.ComponentList(Player, 100),
    Sprite: gbe.ComponentList(Sprite, 100),
});
    