# Paint.Zig

[![Build and Test](https://github.com/christianhelle/paintdotzig/actions/workflows/build.yml/badge.svg)](https://github.com/christianhelle/paintdotzig/actions/workflows/build.yml)

A fast, cross-platform image and photo editing application built with [Zig](https://ziglang.org/), inspired by [Paint.NET](https://www.getpaint.net/).

> **Goals:** Maximum performance, minimal memory usage, and a responsive immediate-mode UI — designed like a game for real-time interaction.

## Features

- **Layered canvas** — multiple layers with visibility, opacity, and blend modes (Normal, Multiply, Screen, Overlay)
- **Drawing tools** — Pencil, Brush (soft/hard), Eraser, Flood Fill, and Shape tools (Line, Rectangle, Ellipse)
- **Undo/Redo** — up to 50 levels of history using efficient pixel snapshots
- **Zoom & Pan** — mouse wheel zoom, Ctrl+= / Ctrl+- keyboard shortcuts
- **Image I/O** — pure-Zig BMP read/write (no external C dependencies for core library)
- **Keyboard shortcuts** — `P` pencil, `B` brush, `E` eraser, `F` fill, `L` line, `R` rectangle, `O` ellipse

## Requirements

- [Zig 0.15.x](https://ziglang.org/download/)
- [SDL2](https://www.libsdl.org/) development libraries

```bash
# Ubuntu / Debian
sudo apt-get install libsdl2-dev

# macOS
brew install sdl2

# Windows: download SDL2-devel from https://github.com/libsdl-org/SDL/releases
```

## Building

```bash
# Run unit tests (no SDL2 required)
zig build test

# Build the application
zig build

# Run the application
zig build run

# Optimised release build
zig build -Doptimize=ReleaseFast
```

## Project Structure

```
src/
├── main.zig          ← Application entry point and SDL2 event loop
├── app.zig           ← Application state (tools, viewport, history)
├── canvas.zig        ← Layered pixel buffer
├── color.zig         ← Rgba, Hsv, Hsl types and conversions
├── history.zig       ← Undo/redo history
├── image.zig         ← BMP image format reader/writer
├── root.zig          ← Library root module
├── tools/
│   ├── pencil.zig    ← Pencil tool (Bresenham line)
│   ├── brush.zig     ← Soft/hard brush
│   ├── eraser.zig    ← Eraser tool
│   ├── fill.zig      ← Flood fill with tolerance
│   └── shapes.zig    ← Rectangle, ellipse, line shapes
└── ui/
    └── renderer.zig  ← SDL2 renderer wrapper
```

## License

MIT
