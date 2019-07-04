@REM zig build-lib -target wasm32-freestanding --release-small src/main_web.zig
@echo off
zig build-lib --cache off --color on -target wasm32-freestanding src/main_web.zig 
