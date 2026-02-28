# Paint.Zig Copilot Instructions

## Project Overview
Paint.Zig is a fast, cross-platform image and photo editing application built with Zig, inspired by Paint.NET. It targets performance and low memory usage through Zig's zero-overhead abstractions and an immediate-mode, game-loop-style UI powered by SDL2.

## Architecture

```
src/
├── main.zig          ← SDL2 window, event loop, immediate-mode rendering
├── app.zig           ← Application state (tool selection, viewport, undo/redo)
├── canvas.zig        ← Layered pixel buffer (Canvas, Layer types)
├── color.zig         ← Color types: Rgba, Hsv, Hsl with conversion/blending
├── history.zig       ← Undo/redo via pixel snapshots (command pattern)
├── image.zig         ← Pure-Zig BMP read/write; Image type
├── root.zig          ← Library root, re-exports all modules
├── tools/
│   ├── pencil.zig    ← Bresenham line drawing
│   ├── brush.zig     ← Soft/hard circular brush with spacing
│   ├── eraser.zig    ← Circular eraser with opacity
│   ├── fill.zig      ← Flood fill with tolerance (stack-based DFS)
│   └── shapes.zig    ← Rectangle, ellipse, line drawing
└── ui/
    └── renderer.zig  ← SDL2 renderer wrapper
```

## Zig Version
**Zig 0.15.x** — use the 0.15 API. Key differences from older versions:
- `std.ArrayList(T)` is now **unmanaged** (no stored allocator).
  - Init: `std.ArrayList(T){}`
  - Deinit: `list.deinit(allocator)`
  - Append: `try list.append(allocator, item)`
  - Pop/orderedRemove/clearRetainingCapacity: no allocator needed
- For managed ArrayList (stored allocator, `.writer()` method): `std.array_list.Managed(T).init(allocator)`
- `b.addExecutable` requires `.root_module = b.createModule(.{ .root_source_file = b.path("..."), ... })`

## Coding Guidelines
- **Memory**: Always use explicit allocators; pair every allocation with a `defer deinit()` or `errdefer deinit()`.
- **Error handling**: Return errors with `!T`, propagate with `try`, never silently ignore.
- **Safety**: Bounds-check all pixel accesses; return `null` or skip silently on out-of-bounds rather than panicking.
- **Tests**: Add `test "..."` blocks in each module. Tests must not require SDL2 (keep UI code in `src/ui/`).
- **Naming**: Follow Zig conventions — `camelCase` for functions/variables, `PascalCase` for types, `snake_case` for files.
- **Comments**: Use `///` doc comments on public functions and types; `//` for inline explanations.

## Key Types
- `Rgba` — packed {r,g,b,a: u8}; use `.blend()` for Porter-Duff compositing
- `Canvas` — owns a list of `Layer`s; call `.flatten(allocator)` to composite
- `Layer` — pixel buffer (`[]Rgba`), visibility, opacity, blend mode
- `AppState` — top-level state; call `beginStroke` / `endStroke` around drawing for automatic undo capture
- `History` — max-depth undo/redo stack using `PixelSnapshot` before/after pairs

## Performance Notes
- The rendering loop runs at display refresh rate (VSync via SDL2 `SDL_RENDERER_PRESENTVSYNC`).
- Canvas flattening allocates a temp buffer per frame; consider caching in future.
- Flood fill uses a stack-allocated visited bitmap; for huge canvases consider bit-packing.
- Brush dab spacing is `radius * 0.5` for smooth strokes without redundant pixel writes.

## Adding a New Tool
1. Create `src/tools/mytool.zig` with a draw function that takes `*Canvas` and options.
2. Add the tool variant to `ToolKind` in `src/app.zig`.
3. Wire up mouse events in `src/main.zig`.
4. Re-export from `src/root.zig`.
5. Add comprehensive tests in the new file.

## Adding a New Image Format
1. Implement `readXxx(allocator, reader) !Image` and `writeXxx(image, writer) !void` in a new file under `src/`.
2. Use `std.io.fixedBufferStream` in tests for buffer-based round-trip testing.
3. Add the format to the file-open dialog logic in `src/main.zig`.
