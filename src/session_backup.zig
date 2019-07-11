const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {
    EventInput: gbe.ComponentList(EventInput, 20),
    Player: gbe.ComponentList(Player, 2),
    Gun: gbe.ComponentList(Gun, 2),
    Sprite: gbe.ComponentList(Sprite, 100),
});
