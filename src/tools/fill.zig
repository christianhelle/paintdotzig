//! Flood fill tool using an iterative 4-connected scanline algorithm.

const std = @import("std");
const canvas_mod = @import("../canvas.zig");
const color = @import("../color.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;

pub const FillOptions = struct {
    fill_color: Rgba = Rgba.black,
    /// Maximum color distance (0–255) for tolerance-based fill.
    tolerance: u8 = 0,
};

/// Euclidean color distance (ignoring alpha) in [0, 442].
fn colorDistance(a: Rgba, b: Rgba) u32 {
    const dr = @as(i32, a.r) - @as(i32, b.r);
    const dg = @as(i32, a.g) - @as(i32, b.g);
    const db = @as(i32, a.b) - @as(i32, b.b);
    // Use squared distance scaled to [0,255] range for fast comparison
    const sq = @as(u32, @intCast(dr * dr + dg * dg + db * db));
    return sq;
}

fn toleranceSquared(tol: u8) u32 {
    const t = @as(u32, tol);
    return t * t * 3;
}

fn matchesTarget(candidate: Rgba, target: Rgba, tol_sq: u32) bool {
    return colorDistance(candidate, target) <= tol_sq;
}

/// Perform a flood fill starting at (start_x, start_y) on the active layer.
pub fn floodFill(canvas: *Canvas, start_x: u32, start_y: u32, opts: FillOptions, allocator: std.mem.Allocator) !void {
    const layer = canvas.getActiveLayer();
    const target_color = layer.getPixel(start_x, start_y) orelse return;

    // If target equals fill color exactly (and no tolerance), nothing to do
    if (opts.tolerance == 0 and target_color.eql(opts.fill_color)) return;

    const tol_sq = toleranceSquared(opts.tolerance);
    const w = layer.width;
    const h = layer.height;

    // Visited bitmap
    const visited = try allocator.alloc(bool, w * h);
    defer allocator.free(visited);
    @memset(visited, false);

    // Stack-based DFS
    var stack = std.ArrayList([2]u32){};
    defer stack.deinit(allocator);

    try stack.append(allocator, .{ start_x, start_y });
    visited[start_y * w + start_x] = true;

    while (stack.items.len > 0) {
        const pos = stack.pop().?;
        const x = pos[0];
        const y = pos[1];

        const existing = layer.getPixel(x, y) orelse continue;
        if (!matchesTarget(existing, target_color, tol_sq)) continue;

        layer.setPixel(x, y, opts.fill_color);

        const neighbors = [_][2]i32{
            .{ @as(i32, @intCast(x)) - 1, @as(i32, @intCast(y)) },
            .{ @as(i32, @intCast(x)) + 1, @as(i32, @intCast(y)) },
            .{ @as(i32, @intCast(x)), @as(i32, @intCast(y)) - 1 },
            .{ @as(i32, @intCast(x)), @as(i32, @intCast(y)) + 1 },
        };

        for (neighbors) |n| {
            const nx = n[0];
            const ny = n[1];
            if (nx < 0 or ny < 0) continue;
            const unx: u32 = @intCast(nx);
            const uny: u32 = @intCast(ny);
            if (unx >= w or uny >= h) continue;
            if (visited[uny * w + unx]) continue;

            const nc = layer.getPixel(unx, uny) orelse continue;
            if (matchesTarget(nc, target_color, tol_sq)) {
                visited[uny * w + unx] = true;
                try stack.append(allocator, .{ unx, uny });
            }
        }
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "floodFill fills entire canvas with same color" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 8, 8);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.white);
    try floodFill(&canvas, 0, 0, .{ .fill_color = Rgba.blue, .tolerance = 0 }, allocator);

    for (canvas.getActiveLayer().pixels) |p| {
        try std.testing.expectEqual(Rgba.blue, p);
    }
}

test "floodFill stops at boundary" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 8, 8);
    defer canvas.deinit();

    // Draw a red border
    const layer = canvas.getActiveLayer();
    layer.fill(Rgba.white);
    for (0..8) |x| {
        layer.setPixel(@intCast(x), 0, Rgba.red);
        layer.setPixel(@intCast(x), 7, Rgba.red);
    }
    for (0..8) |y| {
        layer.setPixel(0, @intCast(y), Rgba.red);
        layer.setPixel(7, @intCast(y), Rgba.red);
    }

    // Fill interior with blue
    try floodFill(&canvas, 4, 4, .{ .fill_color = Rgba.blue, .tolerance = 0 }, allocator);

    // Interior should be blue
    try std.testing.expectEqual(Rgba.blue, layer.getPixel(4, 4).?);
    // Border should remain red
    try std.testing.expectEqual(Rgba.red, layer.getPixel(0, 0).?);
    try std.testing.expectEqual(Rgba.red, layer.getPixel(7, 7).?);
    // White should be gone from interior
    try std.testing.expectEqual(Rgba.blue, layer.getPixel(1, 1).?);
}

test "floodFill no-op when target equals fill color" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.red);
    try floodFill(&canvas, 0, 0, .{ .fill_color = Rgba.red, .tolerance = 0 }, allocator);

    // Should still be red (no change)
    for (canvas.getActiveLayer().pixels) |p| {
        try std.testing.expectEqual(Rgba.red, p);
    }
}

test "floodFill with tolerance" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();

    // Fill with slightly different reds
    const layer = canvas.getActiveLayer();
    layer.fill(Rgba{ .r = 250, .g = 0, .b = 0, .a = 255 });
    layer.setPixel(2, 2, Rgba{ .r = 240, .g = 0, .b = 0, .a = 255 });

    try floodFill(&canvas, 0, 0, .{ .fill_color = Rgba.blue, .tolerance = 20 }, allocator);

    // All pixels should be filled because they're within tolerance of the target
    for (layer.pixels) |p| {
        try std.testing.expectEqual(Rgba.blue, p);
    }
}
