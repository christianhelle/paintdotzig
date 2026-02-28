# Paint.Zig - Copilot Instructions

## Project Overview
Paint.Zig is a cross-platform image editor written in Zig, inspired by Paint.NET. The goal is full feature parity with Paint.NET while achieving superior performance through Zig's zero-cost abstractions and explicit memory management.

## Architecture

### Core Modules (`src/core/`)
- `color.zig` - RGBA, HSL, HSV color types with conversions and blending
- `image.zig` - 2D pixel buffer with manipulation primitives
- `layer.zig` - Layer stack with blend modes (normal, multiply, screen, overlay, etc.)
- `history.zig` - Undo/redo system with configurable depth
- `selection.zig` - Selection mask with rect, ellipse, and set operations
- `canvas.zig` - Document model tying layers, selection, and history together

### Effects (`src/effects/`)
- `effects.zig` - Blur, sharpen, noise, emboss

### Adjustments (`src/adjustments/`)
- `adjustments.zig` - Brightness, contrast, hue, saturation, levels, grayscale, sepia, posterize, threshold

### Tools (`src/tools/`)
- `tools.zig` - Brush, line drawing, flood fill, shapes, gradient

### Formats (`src/formats/`)
- `bmp.zig` - BMP read/write

## Coding Conventions
- Use `snake_case` for functions and variables
- Use `PascalCase` for types and structs
- Use `UPPER_CASE` for constants
- Always use `defer` for cleanup (RAII pattern)
- Use `errdefer` for error path cleanup
- Pass allocator explicitly, never use global state
- All public functions should have doc comments (`///`)
- Tests go at the bottom of each file

## Memory Management
- Use `std.mem.Allocator` everywhere, never hardcode allocator choice
- `GeneralPurposeAllocator` in main, `testing.allocator` in tests
- Every allocation must have a corresponding deallocation
- Use arena allocators for per-frame UI allocations
- Images store pixels as `[]Color` (4 bytes per pixel, RGBA)

## Build & Test
```sh
zig build              # Debug build
zig build --release=fast  # Release build
zig build test         # Run all tests
zig build run          # Run the application
```

## Performance Guidelines
- Prefer stack allocation over heap where possible
- Use SIMD for pixel operations when beneficial
- Use thread pools for parallel effect processing
- Minimize allocations in hot paths
- Profile before optimizing

## Error Handling
- Return error unions (`!Type`) for fallible operations
- Use `try` for propagation
- Define specific error sets, avoid generic errors
- Never silently swallow errors

## Testing
- Every module should have comprehensive tests
- Test edge cases: zero-size images, out-of-bounds access, empty selections
- Test roundtrip conversions (e.g., Color -> HSL -> Color)
- Use `testing.allocator` to detect memory leaks
