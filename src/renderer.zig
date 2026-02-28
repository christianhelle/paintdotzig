const std = @import("std");
const img = @import("image.zig");
const Color = img.Color;
const Image = img.Image;
const canvas = @import("canvas.zig");

/// A checkerboard pattern drawn behind transparent areas to visualize alpha.
pub fn drawCheckerboard(output: *Image, cell_size: u32) void {
    const light = Color{ .r = 204, .g = 204, .b = 204 };
    const dark = Color{ .r = 170, .g = 170, .b = 170 };

    var y: u32 = 0;
    while (y < output.height) : (y += 1) {
        var x: u32 = 0;
        while (x < output.width) : (x += 1) {
            const cell_x = if (cell_size > 0) x / cell_size else 0;
            const cell_y = if (cell_size > 0) y / cell_size else 0;
            const color = if ((cell_x + cell_y) % 2 == 0) light else dark;
            output.pixels[@as(usize, y) * @as(usize, output.width) + @as(usize, x)] = color;
        }
    }
}

/// Composite the image onto the output buffer (with checkerboard behind transparency).
pub fn renderComposite(source: *const Image, output: *Image) void {
    drawCheckerboard(output, 8);
    const len = @min(source.pixels.len, output.pixels.len);
    for (output.pixels[0..len], source.pixels[0..len]) |*dst, src| {
        dst.* = Color.blend(dst.*, src);
    }
}

/// Draw a dashed selection rectangle outline onto the output.
pub fn drawSelectionOutline(output: *Image, x: i32, y: i32, w: u32, h: u32, dash_phase: u32) void {
    if (w == 0 or h == 0) return;
    const wi: i32 = @intCast(w);
    const hi: i32 = @intCast(h);

    // Top edge
    var ix: i32 = x;
    while (ix < x + wi) : (ix += 1) {
        const phase = @as(u32, @intCast(@mod(ix - x, 8)));
        const color = if ((phase + dash_phase) % 8 < 4) Color.black else Color.white;
        output.blendPixel(ix, y, color);
    }
    // Bottom edge
    ix = x;
    while (ix < x + wi) : (ix += 1) {
        const phase = @as(u32, @intCast(@mod(ix - x, 8)));
        const color = if ((phase + dash_phase) % 8 < 4) Color.black else Color.white;
        output.blendPixel(ix, y + hi - 1, color);
    }
    // Left edge
    var iy: i32 = y;
    while (iy < y + hi) : (iy += 1) {
        const phase = @as(u32, @intCast(@mod(iy - y, 8)));
        const color = if ((phase + dash_phase) % 8 < 4) Color.black else Color.white;
        output.blendPixel(x, iy, color);
    }
    // Right edge
    iy = y;
    while (iy < y + hi) : (iy += 1) {
        const phase = @as(u32, @intCast(@mod(iy - y, 8)));
        const color = if ((phase + dash_phase) % 8 < 4) Color.black else Color.white;
        output.blendPixel(x + wi - 1, iy, color);
    }
}

/// Render the toolbar area background.
pub fn fillToolbar(output: *Image, toolbar_height: u32) void {
    const bg = Color{ .r = 50, .g = 50, .b = 50 };
    var y: u32 = 0;
    while (y < @min(toolbar_height, output.height)) : (y += 1) {
        var x: u32 = 0;
        while (x < output.width) : (x += 1) {
            output.pixels[@as(usize, y) * @as(usize, output.width) + @as(usize, x)] = bg;
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "drawCheckerboard fills all pixels" {
    const allocator = std.testing.allocator;
    var output = try Image.init(allocator, 16, 16);
    defer output.deinit();

    drawCheckerboard(&output, 8);
    // No pixel should be transparent
    for (output.pixels) |p| {
        try std.testing.expect(p.a == 255);
    }
}

test "drawCheckerboard alternating pattern" {
    const allocator = std.testing.allocator;
    var output = try Image.init(allocator, 16, 16);
    defer output.deinit();

    drawCheckerboard(&output, 8);
    const p00 = output.getPixel(0, 0).?;
    const p80 = output.getPixel(8, 0).?;
    // Adjacent cells should differ
    try std.testing.expect(!p00.eql(p80));
}

test "renderComposite blends onto checkerboard" {
    const allocator = std.testing.allocator;
    var source = try Image.init(allocator, 4, 4);
    defer source.deinit();

    source.setPixel(0, 0, Color{ .r = 255, .g = 0, .b = 0, .a = 128 });

    var output = try Image.init(allocator, 4, 4);
    defer output.deinit();

    renderComposite(&source, &output);
    const result = output.getPixel(0, 0).?;
    // Should have non-zero red from blending
    try std.testing.expect(result.r > 0);
    try std.testing.expect(result.a == 255);
}

test "drawSelectionOutline draws on edges" {
    const allocator = std.testing.allocator;
    var output = try Image.init(allocator, 20, 20);
    defer output.deinit();

    output.fill(Color{ .r = 128, .g = 128, .b = 128 });
    drawSelectionOutline(&output, 2, 2, 10, 10, 0);

    // Top-left corner should be either black or white (not gray)
    const corner = output.getPixel(2, 2).?;
    try std.testing.expect(corner.eql(Color.black) or corner.eql(Color.white));
}

test "fillToolbar fills top region" {
    const allocator = std.testing.allocator;
    var output = try Image.init(allocator, 10, 20);
    defer output.deinit();

    output.fill(Color.white);
    fillToolbar(&output, 5);

    const toolbar_pixel = output.getPixel(0, 0).?;
    try std.testing.expectEqual(@as(u8, 50), toolbar_pixel.r);

    const canvas_pixel = output.getPixel(0, 10).?;
    try std.testing.expect(canvas_pixel.eql(Color.white));
}
