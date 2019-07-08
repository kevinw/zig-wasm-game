usingnamespace @import("math3d.zig");

const SceneNode = struct {
    parent: ?*SceneNode,
    matrix: Mat4x4,
};
