const std = @import("std");
const Builder = std.build.Builder;
const Step = std.build.Step;
const Target = std.build.Target;
const CrossTarget = std.build.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;

const warn = @import("std").debug.warn;
const builtin = @import("builtin");
const build_tools = @import("./build_tools.zig");

const WINDOWS = true;

const VCPKG_PATH = "../vcpkg/installed/x64-windows/";

pub fn commonStepSetup(libOrExe: *LibExeObjStep) void {
    libOrExe.addPackagePath("gbe", "gbe/src/gbe.zig");
}

pub fn createWasmStep(b: *Builder) *LibExeObjStep {
    const wasmLib = b.addStaticLibrary("main_web", "src/main_web.zig");
    wasmLib.setTheTarget(Target{
        .Cross = CrossTarget{
            .arch = .wasm32,
            .os = .freestanding,
            .abi = .musl,
        },
    });
    commonStepSetup(wasmLib);
    return wasmLib;
}

pub fn createNativeStep(b: *Builder) *LibExeObjStep {
    var exe = b.addExecutable("game", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addIncludeDir(".");

    build_tools.addEnvIncludePaths(exe); // for windows headers

    exe.addIncludeDir("lib");

    exe.addIncludeDir("lib/glad/include");
    exe.addCSourceFile("lib/glad/src/glad.c", [_][]const u8{"-std=c99"});

    commonStepSetup(exe);

    // TODO: make glfw a submodule and invoke its build.zig from here
    exe.addLibPath("../glfw/zig-cache/lib");
    exe.addIncludeDir("../glfw/include");
    exe.linkSystemLibrary("glfw");

    // nuklear
    exe.addCSourceFile("lib/nuklear_glfw3.c", [_][]const u8{"-std=c99"});
    exe.addIncludeDir("../nuklear");

    // for libraries installed by vcpkg
    exe.addIncludeDir(VCPKG_PATH ++ "include");
    exe.addLibPath(VCPKG_PATH ++ "lib");

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("libpng16");

    // windows specific
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("shell32");

    var args = std.ArrayList([]const u8).init(b.allocator);
    args.append("C:\\Users\\Kevin\\AppData\\Local\\Programs\\Python\\Python37-32\\python.exe") catch unreachable;
    args.append("component_codegen.py") catch unreachable;
    const codegen_step = b.addSystemCommand(args.toSliceConst());
    exe.step.dependOn(&codegen_step.step);

    return exe;
}

pub fn build(b: *Builder) void {
    const exe = createNativeStep(b);
    exe.setOutputDir(".");
    b.default_step.dependOn(&exe.step);

    // create a "play" command for running the native build
    const run = exe.run();
    const play = b.step("play", "Play the native build");
    play.dependOn(&run.step);

    const wasmLib = createWasmStep(b);
    wasmLib.setOutputDir(".");
    const wasmStep = b.step("wasm", "Build for WASM");
    wasmStep.dependOn(&wasmLib.step);
}
