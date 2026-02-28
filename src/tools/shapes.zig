//! Shape drawing tools: rectangle, ellipse, and line.

const std = @import("std");
const canvas_mod = @import("../canvas.zig");
const color = @import("../color.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;

pub const ShapeOptions = struct {
    stroke_color: Rgba = Rgba.black,
    fill_color: ?Rgba = null,
    /// Stroke width in pixels.
    stroke_width: u32 = 1,
};

/// Draw a rectangle outline (and optional fill) from (x1,y1) to (x2,y2).
pub fn drawRect(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, opts: ShapeOptions) void {
    const left = @min(x1, x2);
    const right = @max(x1, x2);
    const top = @min(y1, y2);
    const bottom = @max(y1, y2);

    // Fill first
    if (opts.fill_color) |fc| {
        var y = top;
        while (y <= bottom) : (y += 1) {
            var x = left;
            while (x <= right) : (x += 1) {
                setPixelClamped(canvas, x, y, fc);
            }
        }
    }

    // Draw stroke
    const sw: i32 = @intCast(opts.stroke_width);
    var i: i32 = 0;
    while (i < sw) : (i += 1) {
        // Top edge
        var x = left;
        while (x <= right) : (x += 1) {
            setPixelClamped(canvas, x, top + i, opts.stroke_color);
            setPixelClamped(canvas, x, bottom - i, opts.stroke_color);
        }
        // Left/right edges
        var y = top;
        while (y <= bottom) : (y += 1) {
            setPixelClamped(canvas, left + i, y, opts.stroke_color);
            setPixelClamped(canvas, right - i, y, opts.stroke_color);
        }
    }
}

/// Draw an ellipse inscribed in the bounding box (x1,y1)–(x2,y2).
pub fn drawEllipse(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, opts: ShapeOptions) void {
    const left = @min(x1, x2);
    const right = @max(x1, x2);
    const top = @min(y1, y2);
    const bottom = @max(y1, y2);

    const cx: f32 = @as(f32, @floatFromInt(left + right)) * 0.5;
    const cy: f32 = @as(f32, @floatFromInt(top + bottom)) * 0.5;
    const rx: f32 = @as(f32, @floatFromInt(right - left)) * 0.5;
    const ry: f32 = @as(f32, @floatFromInt(bottom - top)) * 0.5;

    if (rx <= 0 or ry <= 0) return;

    var py = top;
    while (py <= bottom) : (py += 1) {
        var px = left;
        while (px <= right) : (px += 1) {
            const nx = (@as(f32, @floatFromInt(px)) - cx) / rx;
            const ny = (@as(f32, @floatFromInt(py)) - cy) / ry;
            const d = nx * nx + ny * ny;

            if (opts.fill_color) |fc| {
                if (d <= 1.0) setPixelClamped(canvas, px, py, fc);
            }

            // Stroke: pixels on the ellipse boundary
            const sw: f32 = @floatFromInt(opts.stroke_width);
            const inner_rx = @max(0.0, rx - sw);
            const inner_ry = @max(0.0, ry - sw);
            const inner_nx = if (inner_rx > 0) (@as(f32, @floatFromInt(px)) - cx) / inner_rx else 0;
            const inner_ny = if (inner_ry > 0) (@as(f32, @floatFromInt(py)) - cy) / inner_ry else 0;
            const d_inner = inner_nx * inner_nx + inner_ny * inner_ny;

            if (d <= 1.0 and d_inner >= 1.0) {
                setPixelClamped(canvas, px, py, opts.stroke_color);
            }
        }
    }
}

/// Draw a straight line from (x0, y0) to (x1, y1) with the stroke color.
pub fn drawLine(canvas: *Canvas, x0: i32, y0: i32, x1: i32, y1: i32, opts: ShapeOptions) void {
    var cx = x0;
    var cy = y0;
    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err: i32 = @intCast(dx);
    err -= @intCast(dy);

    while (true) {
        setPixelClamped(canvas, cx, cy, opts.stroke_color);
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

fn setPixelClamped(canvas: *Canvas, x: i32, y: i32, c: Rgba) void {
    if (x < 0 or y < 0) return;
    canvas.getActiveLayer().setPixel(@intCast(x), @intCast(y), c);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "drawRect stroke" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    drawRect(&canvas, 2, 2, 6, 6, .{ .stroke_color = Rgba.red, .stroke_width = 1 });

    // Corners should be red
    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(2, 2).?);
    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(6, 6).?);
    // Interior should be transparent (no fill)
    try std.testing.expectEqual(Rgba.transparent, canvas.getActiveLayer().getPixel(4, 4).?);
}

test "drawRect fill" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    drawRect(&canvas, 2, 2, 6, 6, .{
        .stroke_color = Rgba.red,
        .fill_color = Rgba.blue,
        .stroke_width = 1,
    });

    // Interior should be blue (stroke is drawn on top)
    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(2, 2).?);
    try std.testing.expectEqual(Rgba.blue, canvas.getActiveLayer().getPixel(4, 4).?);
}

test "drawEllipse paints center" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    drawEllipse(&canvas, 5, 5, 25, 25, .{
        .stroke_color = Rgba.green,
        .fill_color = Rgba.green,
        .stroke_width = 1,
    });

    // Center of ellipse should be green
    try std.testing.expectEqual(Rgba.green, canvas.getActiveLayer().getPixel(15, 15).?);
    // Corners outside ellipse should be transparent
    try std.testing.expectEqual(Rgba.transparent, canvas.getActiveLayer().getPixel(0, 0).?);
}

test "drawLine" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    drawLine(&canvas, 0, 0, 8, 0, .{ .stroke_color = Rgba.white, .stroke_width = 1 });

    for (0..9) |x| {
        try std.testing.expectEqual(Rgba.white, canvas.getActiveLayer().getPixel(@intCast(x), 0).?);
    }
}
