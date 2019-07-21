const std = @import("std");
const Builder = @import("std").build.Builder;
const warn = @import("std").debug.warn;
const builtin = @import("builtin");

//const WIN_SDK_PATH = "C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.16299.0\\";
const VCPKG_PATH = "../vcpkg/installed/x64-windows/";
/// Split the INCLUDE env var by the semicolon character and add each path to
//the given step's include paths.
pub fn addEnvIncludePaths(libExeObjStep: *std.build.LibExeObjStep) void {
    const b = libExeObjStep.builder;
    const env_map = std.process.getEnvMap(b.allocator) catch unreachable;
    if (env_map.get("INCLUDE")) |includes| {
        var it = std.mem.separate(includes, ";");
        while (it.next()) |path|
            libExeObjStep.addIncludeDir(path);
    }
}

const WINDOWS = true;

pub fn build(b: *Builder) void {
    var exe = b.addExecutable("game", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addIncludeDir(".");

    addEnvIncludePaths(exe); // for windows headers

    exe.addIncludeDir("lib/glad/include");
    exe.addCSourceFile("lib/glad/src/glad.c", [_][]const u8{"-std=c99"});

    exe.addPackagePath("gbe", "gbe/src/gbe.zig");

    // for libraries installed by vcpkg
    exe.addIncludeDir(VCPKG_PATH ++ "include");
    exe.addLibPath(VCPKG_PATH ++ "lib");

    //exe.setVerboseLink(true);

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("glfw");

    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("libpng16");

    // exe.addIncludeDir("../z/Chipmunk2D/include");
    // exe.addLibPath("../z/Chipmunk2D/zig-cache/lib");
    // exe.linkSystemLibrary("chipmunk.lib");

    // TODO: make glfw a submodule and invoke its build.zig from here
    exe.addLibPath("../glfw/zig-cache/lib");

    var args = std.ArrayList([]const u8).init(b.allocator);
    args.append("C:\\Users\\Kevin\\AppData\\Local\\Programs\\Python\\Python37-32\\python.exe") catch unreachable;
    args.append("component_codegen.py") catch unreachable;

    const codegen_step = b.addSystemCommand(args.toSliceConst());
    exe.step.dependOn(&codegen_step.step);

    b.default_step.dependOn(&exe.step);

    const play = b.step("play", "Play the game");
    const run = exe.run();
    play.dependOn(&run.step);
}
