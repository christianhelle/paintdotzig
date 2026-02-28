//! Brush tool: draws anti-aliased or soft circular strokes.

const std = @import("std");
const canvas_mod = @import("../canvas.zig");
const color = @import("../color.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;
const math = std.math;

pub const BrushOptions = struct {
    foreground: Rgba = Rgba.black,
    /// Brush radius in pixels.
    radius: f32 = 5.0,
    /// Opacity 0.0–1.0 (applied on top of the color's alpha).
    opacity: f32 = 1.0,
    /// When true, applies a smooth falloff from center to edge.
    soft: bool = true,
};

/// Paint a single circular brush dab at (cx, cy).
pub fn drawDab(canvas: *Canvas, cx: f32, cy: f32, opts: BrushOptions) void {
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

            const alpha_factor: f32 = if (opts.soft)
                math.clamp(1.0 - (dist / r), 0.0, 1.0)
            else
                1.0;

            const final_opacity = opts.opacity * alpha_factor;
            const src = opts.foreground.withAlpha(final_opacity);
            const dst = layer.getPixel(upx, upy) orelse continue;
            layer.setPixel(upx, upy, dst.blend(src));
        }
    }
}

/// Draw a brush stroke from (x0, y0) to (x1, y1), spacing dabs evenly.
pub fn drawStroke(canvas: *Canvas, x0: f32, y0: f32, x1: f32, y1: f32, opts: BrushOptions) void {
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = @sqrt(dx * dx + dy * dy);

    if (len < 0.5) {
        drawDab(canvas, x0, y0, opts);
        return;
    }

    // Space dabs at half-radius intervals for smooth strokes
    const spacing = @max(0.5, opts.radius * 0.5);
    const steps: u32 = @intFromFloat(@ceil(len / spacing));

    var i: u32 = 0;
    while (i <= steps) : (i += 1) {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
        const x = x0 + dx * t;
        const y = y0 + dy * t;
        drawDab(canvas, x, y, opts);
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "drawDab paints center pixel" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    const opts = BrushOptions{ .foreground = Rgba.red, .radius = 3.0, .opacity = 1.0, .soft = false };
    drawDab(&canvas, 10.0, 10.0, opts);

    const center = canvas.getActiveLayer().getPixel(10, 10).?;
    try std.testing.expectEqual(@as(u8, 255), center.r);
    try std.testing.expectEqual(@as(u8, 0), center.g);
}

test "drawDab hard brush covers radius" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    const opts = BrushOptions{ .foreground = Rgba.blue, .radius = 4.0, .opacity = 1.0, .soft = false };
    drawDab(&canvas, 15.0, 15.0, opts);

    // Pixels within radius should be painted
    const within = canvas.getActiveLayer().getPixel(15, 15).?;
    try std.testing.expectEqual(@as(u8, 255), within.b);

    // Pixels far outside should be untouched
    const outside = canvas.getActiveLayer().getPixel(0, 0).?;
    try std.testing.expectEqual(Rgba.transparent, outside);
}

test "drawDab soft brush center is opaque" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    const opts = BrushOptions{ .foreground = Rgba.white, .radius = 5.0, .opacity = 1.0, .soft = true };
    drawDab(&canvas, 15.0, 15.0, opts);

    const center = canvas.getActiveLayer().getPixel(15, 15).?;
    try std.testing.expectEqual(@as(u8, 255), center.r);
}

test "drawStroke paints both endpoints" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 64, 64);
    defer canvas.deinit();

    const opts = BrushOptions{ .foreground = Rgba.green, .radius = 2.0, .opacity = 1.0, .soft = false };
    drawStroke(&canvas, 5.0, 5.0, 55.0, 5.0, opts);

    const start = canvas.getActiveLayer().getPixel(5, 5).?;
    const end_px = canvas.getActiveLayer().getPixel(55, 5).?;
    try std.testing.expectEqual(@as(u8, 255), start.g);
    try std.testing.expectEqual(@as(u8, 255), end_px.g);
}

test "drawStroke single point" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    const opts = BrushOptions{ .foreground = Rgba.red, .radius = 2.0, .opacity = 1.0, .soft = false };
    drawStroke(&canvas, 10.0, 10.0, 10.0, 10.0, opts);

    const p = canvas.getActiveLayer().getPixel(10, 10).?;
    try std.testing.expectEqual(@as(u8, 255), p.r);
}
