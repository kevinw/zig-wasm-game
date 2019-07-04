const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

//pub fn build(b: *Builder) void {
//    const mode = b.standardReleaseOptions();
//
//    var wasmLib = b.addStaticLibrary("main_web", "src/main_web.zig");
//    //wasmLib.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Abi.gnu);
//    wasmLib.setTarget(builtin.Arch.wasm32, builtin.Os.freestanding, builtin.Abi.gnu);
//    wasmLib.setBuildMode(mode);
//
//    b.default_step.dependOn(&wasmLib.step);
//    b.installArtifact(wasmLib);
//}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;

    var exe = b.addExecutable("tetris", "src/main.zig");
    exe.setBuildMode(mode);

    if (windows) {
        exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Abi.gnu);
    }

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("png");
    exe.linkSystemLibrary("z");

    b.default_step.dependOn(&exe.step);

    b.installArtifact(exe);

    const play = b.step("play", "Play the game");
    const run = exe.run();
    play.dependOn(&run.step);
}
