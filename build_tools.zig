const std = @import("std");
const Builder = @import("std").build.Builder;

//const WIN_SDK_PATH = "C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.16299.0\\";
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

//exe.setVerboseLink(true);
