# Paint.Zig

[![CI](https://github.com/christianhelle/paintdotzig/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/paintdotzig/actions/workflows/ci.yml)

A fast, cross-platform image editor written in [Zig](https://ziglang.org/), inspired by [Paint.NET](https://www.getpaint.net/). Built for maximum performance and minimal memory footprint using an immediate-mode GPU-accelerated rendering approach.

## Features

### Core
- **Layer system** with blend modes (normal, multiply, screen, overlay, darken, lighten, color dodge/burn, hard/soft light, difference, exclusion, additive)
- **Unlimited undo/redo** history
- **Selection tools** with rectangle, ellipse, and set operations (union, intersect, subtract)
- **Color management** with RGBA, HSL, and HSV color spaces

### Drawing Tools
- Brush/pencil with configurable size, hardness, and opacity
- Line drawing (Bresenham's algorithm)
- Flood fill with adjustable tolerance
- Rectangle and ellipse drawing (outline and filled)
- Linear gradient (horizontal and vertical)

### Image Effects
- Gaussian blur
- Sharpen (unsharp mask)
- Add noise
- Emboss

### Adjustments
- Brightness & Contrast
- Hue & Saturation
- Levels
- Invert colors
- Grayscale
- Sepia tone
- Posterize
- Threshold

### File Formats
- BMP (read/write, 24-bit and 32-bit)

## Requirements

- [Zig](https://ziglang.org/download/) 0.15.2 or later

## Build

```sh
# Debug build
zig build

# Release build (optimized for speed)
zig build --release=fast

# Run
zig build run

# Run tests
zig build test
```

## Project Structure

```
src/
├── main.zig              # Entry point
├── core/
│   ├── color.zig         # RGBA/HSL/HSV color types
│   ├── image.zig         # 2D pixel buffer
│   ├── layer.zig         # Layer stack and blend modes
│   ├── history.zig       # Undo/redo system
│   ├── selection.zig     # Selection mask
│   └── canvas.zig        # Document model
├── effects/
│   └── effects.zig       # Blur, sharpen, noise, emboss
├── adjustments/
│   └── adjustments.zig   # Brightness, contrast, hue, levels, etc.
├── tools/
│   └── tools.zig         # Brush, line, fill, shapes, gradient
└── formats/
    └── bmp.zig           # BMP format support
```

## Design Goals

- **Performance first**: Zero-cost abstractions, explicit memory management, SIMD-ready pixel operations
- **Cross-platform**: Windows, macOS, and Linux
- **Paint.NET feature parity**: Full set of tools, effects, adjustments, and file formats
- **Minimal dependencies**: Pure Zig with no external runtime dependencies for core

## Roadmap

- [ ] GPU-accelerated rendering with raylib
- [ ] Tabbed document interface with live thumbnails
- [ ] PNG, JPEG, TGA, WebP, TIFF format support
- [ ] Shape tools (curves, Bezier)
- [ ] Text tool
- [ ] Magic wand selection
- [ ] Clone stamp
- [ ] Red-eye removal
- [ ] 3D Rotate/Zoom effect
- [ ] Curves and advanced color adjustments
- [ ] Pen/tablet pressure sensitivity
- [ ] Snap package for Ubuntu

## License

MIT
