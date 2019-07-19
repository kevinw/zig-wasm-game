@REM zig build-lib -target wasm32-freestanding --release-small src/main_web.zig
@echo off
python component_codegen.py && ^
zig build-lib --pkg-begin gbe gbe/src/gbe.zig --cache off --color on -target wasm32-freestanding src/main_web.zig --pkg-end
if %errorlevel% neq 0 exit /b %errorlevel%
echo Compiled successfully at %time%
