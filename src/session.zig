// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    Destroy_Timer: gbe.ComponentList(Destroy_Timer),
    Gun: gbe.ComponentList(Gun),
    Mover: gbe.ComponentList(Mover),
    Player: gbe.ComponentList(Player),
    Sprite: gbe.ComponentList(Sprite),
});
    