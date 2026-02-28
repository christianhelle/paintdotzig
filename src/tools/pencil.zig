//! Pencil tool: draws individual pixels with hard edges along a Bresenham line.

const std = @import("std");
const canvas_mod = @import("../canvas.zig");
const color = @import("../color.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;

pub const PencilOptions = struct {
    /// Drawing color.
    foreground: Rgba = Rgba.black,
    /// Size in pixels (1 = single pixel, 3 = 3×3 square, etc.).
    size: u32 = 1,
};

/// Draw a single pixel (or a square of `size` pixels) at (x, y).
pub fn drawPoint(canvas: *Canvas, x: i32, y: i32, opts: PencilOptions) void {
    const half: i32 = @intCast(opts.size / 2);
    var dy: i32 = -half;
    while (dy <= half) : (dy += 1) {
        var dx: i32 = -half;
        while (dx <= half) : (dx += 1) {
            const px = x + dx;
            const py = y + dy;
            if (px < 0 or py < 0) continue;
            canvas.getActiveLayer().setPixel(@intCast(px), @intCast(py), opts.foreground);
        }
    }
}

/// Draw a line from (x0, y0) to (x1, y1) using Bresenham's algorithm.
pub fn drawLine(canvas: *Canvas, x0: i32, y0: i32, x1: i32, y1: i32, opts: PencilOptions) void {
    var cx = x0;
    var cy = y0;
    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err: i32 = @intCast(dx);
    err -= @intCast(dy);

    while (true) {
        drawPoint(canvas, cx, cy, opts);
        if (cx == x1 and cy == y1) break;
        const e2 = err * 2;
        if (e2 > -@as(i32, @intCast(dy))) {
            err -= @intCast(dy);
            cx += sx;
        }
        if (e2 < @as(i32, @intCast(dx))) {
            err += @intCast(dx);
            cy += sy;
        }
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "drawPoint single pixel" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.red, .size = 1 };
    drawPoint(&canvas, 5, 5, opts);

    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(5, 5).?);
    try std.testing.expectEqual(Rgba.transparent, canvas.getActiveLayer().getPixel(4, 5).?);
}

test "drawPoint square brush" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.blue, .size = 3 };
    drawPoint(&canvas, 5, 5, opts);

    // Center and immediate neighbors should be set
    var dy: i32 = -1;
    while (dy <= 1) : (dy += 1) {
        var dx: i32 = -1;
        while (dx <= 1) : (dx += 1) {
            const px: u32 = @intCast(5 + dx);
            const py: u32 = @intCast(5 + dy);
            try std.testing.expectEqual(Rgba.blue, canvas.getActiveLayer().getPixel(px, py).?);
        }
    }
}

test "drawLine horizontal" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.green, .size = 1 };
    drawLine(&canvas, 0, 4, 7, 4, opts);

    for (0..8) |x| {
        try std.testing.expectEqual(Rgba.green, canvas.getActiveLayer().getPixel(@intCast(x), 4).?);
    }
    // Row above should be untouched
    try std.testing.expectEqual(Rgba.transparent, canvas.getActiveLayer().getPixel(3, 3).?);
}

test "drawLine vertical" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.white, .size = 1 };
    drawLine(&canvas, 2, 0, 2, 7, opts);

    for (0..8) |y| {
        try std.testing.expectEqual(Rgba.white, canvas.getActiveLayer().getPixel(2, @intCast(y)).?);
    }
}

test "drawLine diagonal" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.red, .size = 1 };
    drawLine(&canvas, 0, 0, 4, 4, opts);

    for (0..5) |i| {
        try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(@intCast(i), @intCast(i)).?);
    }
}

test "drawLine single point" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    const opts = PencilOptions{ .foreground = Rgba.red, .size = 1 };
    drawLine(&canvas, 3, 3, 3, 3, opts);

    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(3, 3).?);
}
