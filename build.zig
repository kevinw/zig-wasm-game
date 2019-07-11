const std = @import("std");
const Builder = @import("std").build.Builder;
const warn = @import("std").debug.warn;
const builtin = @import("builtin");

const WIN_SDK_PATH = "C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.16299.0\\";
const VCPKG_PATH = "../vcpkg/installed/x86-windows/";

pub fn build(b: *Builder) void {
    var exe = b.addExecutable("game", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addIncludeDir(".");

    // for windows headers
    exe.addIncludeDir(WIN_SDK_PATH ++ "shared");
    exe.addIncludeDir(WIN_SDK_PATH ++ "um");

    exe.addPackagePath("gbe", "gbe/src/gbe.zig");

    // for libraries installed by vcpkg
    exe.addIncludeDir(VCPKG_PATH ++ "include");
    exe.addLibPath(VCPKG_PATH ++ "lib");

    exe.setVerboseLink(true);

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("glfw3dll.lib");

    // exe.addIncludeDir("../z/Chipmunk2D/include");
    // exe.addLibPath("../z/Chipmunk2D/zig-cache/lib");
    // exe.linkSystemLibrary("chipmunk.lib");

    var args = std.ArrayList([]const u8).init(b.allocator);
    args.append("python") catch unreachable;
    args.append("component_codegen.py") catch unreachable;

    const codegen_step = b.addSystemCommand(args.toSliceConst());
    exe.step.dependOn(&codegen_step.step);

    b.default_step.dependOn(&exe.step);

    const play = b.step("play", "Play the game");
    const run = exe.run();
    play.dependOn(&run.step);
}
