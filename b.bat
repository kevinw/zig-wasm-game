@REM zig build-lib -target wasm32-freestanding --release-small src/main_web.zig
@REM @echo off
zig build-lib --pkg-begin gbe gbe/src/gbe.zig --cache off --color on -target wasm32-freestanding src/main_web.zig --pkg-end
