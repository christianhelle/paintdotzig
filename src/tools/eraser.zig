//! Eraser tool: erases pixels to transparent (or background color).

const std = @import("std");
const canvas_mod = @import("../canvas.zig");
const color = @import("../color.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;

pub const EraserOptions = struct {
    /// Eraser radius in pixels.
    radius: f32 = 5.0,
    /// Opacity of erasure 0.0–1.0 (1.0 = fully transparent result).
    opacity: f32 = 1.0,
};

/// Erase a circular area centered at (cx, cy).
pub fn erase(canvas: *Canvas, cx: f32, cy: f32, opts: EraserOptions) void {
    const r = opts.radius;
    const ix_min: i32 = @intFromFloat(@floor(cx - r));
    const iy_min: i32 = @intFromFloat(@floor(cy - r));
    const ix_max: i32 = @intFromFloat(@ceil(cx + r));
    const iy_max: i32 = @intFromFloat(@ceil(cy + r));

    const layer = canvas.getActiveLayer();
    var py = iy_min;
    while (py <= iy_max) : (py += 1) {
        var px = ix_min;
        while (px <= ix_max) : (px += 1) {
            if (px < 0 or py < 0) continue;
            const upx: u32 = @intCast(px);
            const upy: u32 = @intCast(py);

            const dx = @as(f32, @floatFromInt(px)) - cx;
            const dy = @as(f32, @floatFromInt(py)) - cy;
            const dist = @sqrt(dx * dx + dy * dy);
            if (dist > r) continue;

            const existing = layer.getPixel(upx, upy) orelse continue;
            const new_a = @as(f32, @floatFromInt(existing.a)) * (1.0 - opts.opacity);
            layer.setPixel(upx, upy, .{
                .r = existing.r,
                .g = existing.g,
                .b = existing.b,
                .a = @intFromFloat(@round(new_a)),
            });
        }
    }
}

/// Erase a line stroke from (x0, y0) to (x1, y1).
pub fn eraseLine(canvas: *Canvas, x0: f32, y0: f32, x1: f32, y1: f32, opts: EraserOptions) void {
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = @sqrt(dx * dx + dy * dy);

    if (len < 0.5) {
        erase(canvas, x0, y0, opts);
        return;
    }

    const spacing = @max(0.5, opts.radius * 0.5);
    const steps: u32 = @intFromFloat(@ceil(len / spacing));

    var i: u32 = 0;
    while (i <= steps) : (i += 1) {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
        erase(canvas, x0 + dx * t, y0 + dy * t, opts);
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "erase makes pixel transparent" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.red);
    erase(&canvas, 10.0, 10.0, .{ .radius = 2.0, .opacity = 1.0 });

    const center = canvas.getActiveLayer().getPixel(10, 10).?;
    try std.testing.expectEqual(@as(u8, 0), center.a);
}

test "erase partial opacity" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba{ .r = 255, .g = 0, .b = 0, .a = 200 });
    erase(&canvas, 10.0, 10.0, .{ .radius = 2.0, .opacity = 0.5 });

    const center = canvas.getActiveLayer().getPixel(10, 10).?;
    // Alpha should be approximately halved
    try std.testing.expect(center.a > 80 and center.a < 120);
}

test "erase does not affect pixels outside radius" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.white);
    erase(&canvas, 5.0, 5.0, .{ .radius = 2.0, .opacity = 1.0 });

    // Far pixel should be untouched
    const far = canvas.getActiveLayer().getPixel(20, 20).?;
    try std.testing.expectEqual(@as(u8, 255), far.a);
}

test "eraseLine covers endpoints" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 64, 64);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.white);
    eraseLine(&canvas, 5.0, 5.0, 55.0, 5.0, .{ .radius = 2.0, .opacity = 1.0 });

    const start = canvas.getActiveLayer().getPixel(5, 5).?;
    const end_px = canvas.getActiveLayer().getPixel(55, 5).?;
    try std.testing.expectEqual(@as(u8, 0), start.a);
    try std.testing.expectEqual(@as(u8, 0), end_px.a);
}
