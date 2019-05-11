# Tetris 

A simple tetris clone written in [zig programming language](https://github.com/andrewrk/zig).

## Demo

https://raulgrell.github.io/tetris/

## Controls

 * Left/Right/Down Arrow - Move piece left/right/down.
 * Up Arrow - Rotate piece clockwise.
 * Shift - Rotate piece counter clockwise.
 * Space - Drop piece immediately.
 * R - Start new game.
 * P - Pause and unpause game.
 * Escape - Quit.

## Dependencies

 * [Zig compiler](https://github.com/andrewrk/zig) - use the debug build.

### Desktop
 * GLFW
 * libepoxy
 * libpng

### WebGL
 * Browser supporting WebGL

## Building and Running

### Desktop

Run the following command from the project root:

```
zig build
```

### Webgl

Open the index.html file to run. You can also run a local http live server on the project root so the game restarts whenever you make a change.
If you make changes to the zig code, rebuild the wasm binary by running the following command from the project root:

```
zig build-exe -target wasm32-freestanding --release-small src/main_web.zig
```
