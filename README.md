# Paint.Zig

A fast, cross-platform image and photo editor written in [Zig](https://ziglang.org/), inspired by [Paint.NET](https://www.getpaint.net/).

[![CI](https://github.com/christianhelle/paintdotzig/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/paintdotzig/actions/workflows/ci.yml)

## Features

- **Immediate-mode GPU-accelerated UI** powered by [raylib](https://www.raylib.com/) for maximum performance
- **Drawing tools**: Pencil, Brush, Eraser, Flood Fill, Line, Rectangle, Circle, Ellipse, Color Picker
- **Layer system** with blend modes (Normal, Multiply, Screen, Overlay)
- **Undo/redo history** with configurable depth
- **BMP file I/O** (read and write 24-bit and 32-bit BMP files)
- **Keyboard shortcuts**: Ctrl+Z undo, Ctrl+Shift+Z redo, Ctrl+S save, P/B/E/F/L/R/C tool switching
- **Mouse wheel** brush size adjustment
- **Checkerboard transparency** visualization
- **Selection rectangles** with animated marching ants
- **Alpha blending** with src-over compositing
- Zero external dependencies for core modules (only raylib for the GUI)
- Cross-platform: Linux, macOS, Windows

## Prerequisites

### Zig

Install [Zig 0.15.2+](https://ziglang.org/download/).

### raylib (for GUI build)

The GUI executable links against system-installed raylib. The test suite does not require raylib.

**Ubuntu/Debian:**

```sh
sudo apt install libraylib-dev libgl-dev libx11-dev
```

**Build from source:**

```sh
git clone --depth 1 --branch 5.5 https://github.com/raysan5/raylib.git
cd raylib/src && make PLATFORM=PLATFORM_DESKTOP && sudo make install
```

**macOS (Homebrew):**

```sh
brew install raylib
```

## Building

```sh
zig build                        # debug build
zig build --release=fast         # optimized release build
```

The binary is at `zig-out/bin/paintdotzig`.

## Running

```sh
zig build run
```

## Testing

The test suite covers all core modules (image, canvas, layers, tools, history, BMP I/O, renderer) and runs headlessly without requiring a display server:

```sh
zig build test
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `P` | Pencil tool |
| `B` | Brush tool |
| `E` | Eraser tool |
| `F` | Flood fill tool |
| `L` | Line tool |
| `R` | Rectangle tool |
| `C` | Circle tool |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` | Redo |
| `Ctrl+S` | Save as BMP |
| Mouse wheel | Adjust brush size |

## Architecture

All source files live flat in `src/`:

| Module | Responsibility |
|--------|---------------|
| `image.zig` | Core `Color` (RGBA) and `Image` (2D pixel buffer) types |
| `canvas.zig` | Drawing primitives: Bresenham lines, circles, ellipses, flood fill |
| `tools.zig` | Tool state machine: pencil, brush, eraser, fill, shapes, picker |
| `layers.zig` | Layer stack with blend modes and flatten compositing |
| `history.zig` | Undo/redo via snapshot-based history |
| `bmp.zig` | BMP file read/write |
| `renderer.zig` | Software compositing: checkerboard, selection, toolbar |
| `gui.zig` | Raylib-based immediate-mode editor UI |
| `main.zig` | Application entry point |

## License

MIT
