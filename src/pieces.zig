const Vec4 = @import("math3d.zig").Vec4;

pub const Piece = struct {
    name: u8,
    color: Vec4,
    layout: [4][4][4]bool,
};

const x = false;
const O = true;

pub const pieces = [_]Piece{
    Piece{
        .name = 'I',
        .color = Vec4{
            .data = [_]f32{ 0.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, O, O },
                [_]bool{ x, x, x, x },
            },
            [_][4]bool{
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, O, O },
                [_]bool{ x, x, x, x },
            },
            [_][4]bool{
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
            },
        },
    },
    Piece{
        .name = 'O',
        .color = Vec4{
            .data = [_]f32{ 255.0 / 255.0, 255.0 / 255.0, 0.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ O, O, x, x },
            },
        },
    },
    Piece{
        .name = 'T',
        .color = Vec4{
            .data = [_]f32{ 255.0 / 255.0, 0.0 / 255.0, 255.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, O, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ O, O, O, x },
                [_]bool{ x, x, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, O, x },
                [_]bool{ x, O, x, x },
            },
        },
    },
    Piece{
        .name = 'J',
        .color = Vec4{
            .data = [_]f32{ 0.0 / 255.0, 0.0 / 255.0, 255.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ O, x, x, x },
                [_]bool{ O, O, O, x },
                [_]bool{ x, x, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, O, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, O, x },
                [_]bool{ x, x, O, x },
            },
        },
    },
    Piece{
        .name = 'L',
        .color = Vec4{
            .data = [_]f32{ 255.0 / 255.0, 128.0 / 255.0, 0.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, O, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, O, x },
                [_]bool{ O, x, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, x, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, O, x },
                [_]bool{ O, O, O, x },
                [_]bool{ x, x, x, x },
            },
        },
    },
    Piece{
        .name = 'S',
        .color = Vec4{
            .data = [_]f32{ 0.0 / 255.0, 255.0 / 255.0, 0.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, O, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ O, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ x, O, O, x },
                [_]bool{ O, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ O, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, x, x },
            },
        },
    },
    Piece{
        .name = 'Z',
        .color = Vec4{
            .data = [_]f32{ 255.0 / 255.0, 0.0 / 255.0, 0.0 / 255.0, 1.0 },
        },
        .layout = [_][4][4]bool{
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, O, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, O, x },
                [_]bool{ x, O, O, x },
                [_]bool{ x, O, x, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, x, x },
                [_]bool{ O, O, x, x },
                [_]bool{ x, O, O, x },
            },
            [_][4]bool{
                [_]bool{ x, x, x, x },
                [_]bool{ x, x, O, x },
                [_]bool{ x, O, O, x },
                [_]bool{ x, O, x, x },
            },
        },
    },
};
