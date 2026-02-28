# Paint.Zig – Copilot Instructions

Paint.Zig is a cross-platform image and photo editor written in Zig (minimum version 0.15.2), inspired by Paint.NET. It uses raylib as an immediate-mode rendering backend for GPU-accelerated drawing with minimal overhead.

## Build, run, and test

```sh
zig build              # compile → zig-out/bin/paintdotzig (requires raylib)
zig build run          # build + run the editor
zig build test         # run all unit tests (no raylib needed)
```

The test suite is independent of the GUI layer. It exercises the core image, canvas, tool, layer, history, BMP I/O, and renderer modules without requiring a display server or GPU.

## Architecture

All source files live flat in `src/`. The data flow is:

```
main.zig  →  gui.zig (raylib)
                ↓
            tools.zig  ←  canvas.zig
                ↓             ↓
           history.zig   image.zig
                ↓             ↓
           layers.zig   renderer.zig
                ↓
            bmp.zig (file I/O)
```

| File | Responsibility |
|---|---|
| `main.zig` | Entry point; owns the `GeneralPurposeAllocator`; launches the GUI |
| `gui.zig` | Raylib-based immediate-mode GUI; editor state; input handling; toolbar rendering |
| `image.zig` | Core `Color` (RGBA u8) and `Image` (2D pixel buffer) types with alpha blending |
| `canvas.zig` | Drawing primitives: line (Bresenham), rectangle, circle, ellipse, flood fill |
| `tools.zig` | Tool definitions (pencil, brush, eraser, fill, line, shapes, color picker, selection) |
| `layers.zig` | Layer stack with blend modes (normal, multiply, screen, overlay) and flatten |
| `history.zig` | Undo/redo via full-image snapshots with configurable max depth |
| `bmp.zig` | BMP file read/write (32-bit BGRA with BITMAPV4HEADER) |
| `renderer.zig` | Software compositing: checkerboard background, selection outline, toolbar |
| `tests.zig` | Test entry point that imports all non-GUI modules for `zig build test` |

## Key conventions

**Tests are inline.** Every `.zig` file that has logic contains `test` blocks directly in that file. `tests.zig` imports all non-GUI modules, ensuring the test binary transitively covers all inline tests.

**GUI is isolated.** The `gui.zig` module is the only file that depends on raylib. All other modules are pure Zig with no external dependencies, making them easy to test headlessly.

**Color is always RGBA u8.** The `Color` struct uses 8-bit channels with a default alpha of 255. The `toU32`/`fromU32` methods use ABGR layout for little-endian framebuffers.

**Alpha blending uses src-over compositing.** `Color.blend(dst, src)` implements the standard Porter-Duff src-over operation.

**Eraser uses direct pixel writes.** Unlike other tools that use alpha blending, the eraser uses `fillCircleDirect` to overwrite pixels with transparent, ensuring clean erasure.

**History uses snapshot-based undo.** Each push saves a full copy of the pixel buffer. The position pointer tracks the current state in the entry list.

**Source control:** Commit progress to git in small logical chunks with clear one-liner messages. Do not change the committer to Copilot and do not add a Co-Author line.
