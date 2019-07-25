const std = @import("std");
const c = @import("../platform.zig");
const assert = std.debug.assert;
usingnamespace @import("../globals.zig");
usingnamespace @import("../session.zig");

fn removeElement(comptime T: type, list: *std.ArrayList(T), elem: T) bool {
    for (list.toSlice()) |child, i| {
        if (child == elem) {
            const elem2 = list.orderedRemove(i);
            assert(elem == elem2);
            return true;
        }
    }

    return false;
}

pub const Transform = struct {
    const Self = @This();

    parent: ?*Transform = null,
    children: std.ArrayList(*Transform) = std.ArrayList(*Transform).init(c.allocator),

    position: Vec3 = Vec3.zero,
    rotation: Vec3 = Vec3.zero,
    scale: Vec3 = Vec3.one,

    local_matrix: Mat4x4 = Mat4x4.identity,
    world_matrix: Mat4x4 = Mat4x4.identity,

    pub fn setParent(self: *Self, parent: ?*Transform) void {
        // remove us from our parent
        if (self.parent) |current_parent| {
            _ = removeElement(*Transform, &current_parent.children, self);
        }

        // add us to our new parent
        if (parent) |new_parent| {
            new_parent.children.append(self) catch unreachable;
        }

        self.parent = parent;
    }

    fn updateWorldMatrix(self: *Self, parent_world_matrix: Mat4x4) void {
        // compute our world matrix by multiplying our local matrix with
        // our parent's world matrix
        self.world_matrix = self.local_matrix.mult(parent_world_matrix);

        // node do the same for all of our children
        for (self.children.toSlice()) |child| {
            child.updateWorldMatrix(self.world_matrix);
        }
    }
};

pub fn update(gs: *GameSession, transform: *Transform) bool {
    if (transform.parent) |p| {} else {
        transform.updateWorldMatrix(Mat4x4.identity);
    }
    return true;
}