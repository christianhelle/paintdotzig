const std = @import("std");
const img = @import("image.zig");
const Color = img.Color;
const Image = img.Image;

/// Draw a line using Bresenham's algorithm.
pub fn drawLine(image: *Image, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
    var cx = x0;
    var cy = y0;
    const dx: i32 = @intCast(@abs(x1 - x0));
    const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    while (true) {
        image.blendPixel(cx, cy, color);
        if (cx == x1 and cy == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            cx += sx;
        }
        if (e2 <= dx) {
            err += dx;
            cy += sy;
        }
    }
}

/// Draw an axis-aligned rectangle outline.
pub fn drawRect(image: *Image, x: i32, y: i32, w: u32, h: u32, color: Color) void {
    if (w == 0 or h == 0) return;
    const wi: i32 = @intCast(w);
    const hi: i32 = @intCast(h);
    drawLine(image, x, y, x + wi - 1, y, color); // top
    drawLine(image, x, y + hi - 1, x + wi - 1, y + hi - 1, color); // bottom
    drawLine(image, x, y, x, y + hi - 1, color); // left
    drawLine(image, x + wi - 1, y, x + wi - 1, y + hi - 1, color); // right
}

/// Draw a circle outline using the midpoint algorithm.
pub fn drawCircle(image: *Image, cx: i32, cy: i32, radius: u32, color: Color) void {
    if (radius == 0) {
        image.blendPixel(cx, cy, color);
        return;
    }
    var x: i32 = @intCast(radius);
    var y: i32 = 0;
    const r: i32 = @intCast(radius);
    var err: i32 = 1 - r;

    while (x >= y) {
        image.blendPixel(cx + x, cy + y, color);
        image.blendPixel(cx - x, cy + y, color);
        image.blendPixel(cx + x, cy - y, color);
        image.blendPixel(cx - x, cy - y, color);
        image.blendPixel(cx + y, cy + x, color);
        image.blendPixel(cx - y, cy + x, color);
        image.blendPixel(cx + y, cy - x, color);
        image.blendPixel(cx - y, cy - x, color);
        y += 1;
        if (err < 0) {
            err += 2 * y + 1;
        } else {
            x -= 1;
            err += 2 * (y - x) + 1;
        }
    }
}

/// Draw a filled circle.
pub fn fillCircle(image: *Image, cx: i32, cy: i32, radius: u32, color: Color) void {
    if (radius == 0) {
        image.blendPixel(cx, cy, color);
        return;
    }
    const r: i32 = @intCast(radius);
    var dy: i32 = -r;
    while (dy <= r) : (dy += 1) {
        const max_dx_sq = r * r - dy * dy;
        var dx: i32 = -r;
        while (dx <= r) : (dx += 1) {
            if (dx * dx + dy * dy <= max_dx_sq + r) {
                image.blendPixel(cx + dx, cy + dy, color);
            }
        }
    }
}

/// Draw a filled circle using direct pixel writes (no alpha blending).
/// Useful for the eraser tool which needs to overwrite pixels with transparent.
pub fn fillCircleDirect(image: *Image, cx: i32, cy: i32, radius: u32, color: Color) void {
    if (radius == 0) {
        image.setPixel(cx, cy, color);
        return;
    }
    const r: i32 = @intCast(radius);
    var dy: i32 = -r;
    while (dy <= r) : (dy += 1) {
        const max_dx_sq = r * r - dy * dy;
        var dx: i32 = -r;
        while (dx <= r) : (dx += 1) {
            if (dx * dx + dy * dy <= max_dx_sq + r) {
                image.setPixel(cx + dx, cy + dy, color);
            }
        }
    }
}

/// Flood fill starting at (sx, sy), replacing contiguous pixels of the target
/// color with the replacement color. Uses a stack-based iterative algorithm.
pub fn floodFill(image: *Image, sx: i32, sy: i32, replacement: Color, allocator: std.mem.Allocator) !void {
    const target = image.getPixel(sx, sy) orelse return;
    if (target.eql(replacement)) return;

    var stack: std.ArrayListUnmanaged([2]i32) = .empty;
    defer stack.deinit(allocator);
    try stack.append(allocator, .{ sx, sy });

    while (stack.items.len > 0) {
        const pt = stack.pop() orelse break;
        const px = pt[0];
        const py = pt[1];
        const current = image.getPixel(px, py) orelse continue;
        if (!current.eql(target)) continue;

        image.setPixel(px, py, replacement);

        try stack.append(allocator, .{ px + 1, py });
        try stack.append(allocator, .{ px - 1, py });
        try stack.append(allocator, .{ px, py + 1 });
        try stack.append(allocator, .{ px, py - 1 });
    }
}

/// Draw an ellipse outline using the midpoint ellipse algorithm.
pub fn drawEllipse(image: *Image, cx: i32, cy: i32, rx: u32, ry: u32, color: Color) void {
    if (rx == 0 and ry == 0) {
        image.blendPixel(cx, cy, color);
        return;
    }
    const a: i64 = @intCast(rx);
    const b: i64 = @intCast(ry);
    const a2 = a * a;
    const b2 = b * b;

    // Region 1
    var x: i64 = 0;
    var y: i64 = b;
    var d1 = b2 - a2 * b + @divTrunc(a2, 4);

    while (b2 * x <= a2 * y) {
        image.blendPixel(cx + @as(i32, @intCast(x)), cy + @as(i32, @intCast(y)), color);
        image.blendPixel(cx - @as(i32, @intCast(x)), cy + @as(i32, @intCast(y)), color);
        image.blendPixel(cx + @as(i32, @intCast(x)), cy - @as(i32, @intCast(y)), color);
        image.blendPixel(cx - @as(i32, @intCast(x)), cy - @as(i32, @intCast(y)), color);
        x += 1;
        if (d1 < 0) {
            d1 += b2 * (2 * x + 1);
        } else {
            y -= 1;
            d1 += b2 * (2 * x + 1) - 2 * a2 * y;
        }
    }

    // Region 2
    var d2 = b2 * (2 * x + 1) * (2 * x + 1) + 4 * a2 * (y - 1) * (y - 1) - 4 * a2 * b2;
    while (y >= 0) {
        image.blendPixel(cx + @as(i32, @intCast(x)), cy + @as(i32, @intCast(y)), color);
        image.blendPixel(cx - @as(i32, @intCast(x)), cy + @as(i32, @intCast(y)), color);
        image.blendPixel(cx + @as(i32, @intCast(x)), cy - @as(i32, @intCast(y)), color);
        image.blendPixel(cx - @as(i32, @intCast(x)), cy - @as(i32, @intCast(y)), color);
        y -= 1;
        if (d2 > 0) {
            d2 -= 4 * a2 * (2 * y - 1);
        } else {
            x += 1;
            d2 += 4 * b2 * (2 * x + 1) - 4 * a2 * (2 * y - 1);
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "drawLine horizontal" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    drawLine(&image, 0, 5, 9, 5, Color.red);
    var count: usize = 0;
    for (image.pixels) |p| {
        if (p.eql(Color.red)) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), count);
}

test "drawLine vertical" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    drawLine(&image, 3, 0, 3, 9, Color.green);
    var count: usize = 0;
    for (image.pixels) |p| {
        if (p.eql(Color.green)) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), count);
}

test "drawLine diagonal" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    drawLine(&image, 0, 0, 9, 9, Color.blue);
    try std.testing.expect(image.getPixel(0, 0).?.eql(Color.blue));
    try std.testing.expect(image.getPixel(9, 9).?.eql(Color.blue));
    try std.testing.expect(image.getPixel(5, 5).?.eql(Color.blue));
}

test "drawRect produces outline" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    drawRect(&image, 1, 1, 5, 5, Color.white);
    // corners should be set
    try std.testing.expect(image.getPixel(1, 1).?.eql(Color.white));
    try std.testing.expect(image.getPixel(5, 1).?.eql(Color.white));
    try std.testing.expect(image.getPixel(1, 5).?.eql(Color.white));
    try std.testing.expect(image.getPixel(5, 5).?.eql(Color.white));
    // interior should be transparent
    try std.testing.expect(image.getPixel(3, 3).?.eql(Color.transparent));
}

test "drawRect zero dimensions is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    drawRect(&image, 0, 0, 0, 0, Color.red);
    for (image.pixels) |p| {
        try std.testing.expect(p.eql(Color.transparent));
    }
}

test "drawCircle sets pixels at cardinal points" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 20, 20);
    defer image.deinit();

    drawCircle(&image, 10, 10, 5, Color.red);
    // top, bottom, left, right
    try std.testing.expect(image.getPixel(10, 5).?.eql(Color.red));
    try std.testing.expect(image.getPixel(10, 15).?.eql(Color.red));
    try std.testing.expect(image.getPixel(5, 10).?.eql(Color.red));
    try std.testing.expect(image.getPixel(15, 10).?.eql(Color.red));
}

test "drawCircle zero radius draws single pixel" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    drawCircle(&image, 2, 2, 0, Color.green);
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.green));
}

test "fillCircle fills interior" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 20, 20);
    defer image.deinit();

    fillCircle(&image, 10, 10, 3, Color.blue);
    // center should be filled
    try std.testing.expect(image.getPixel(10, 10).?.eql(Color.blue));
    // a point well outside should be transparent
    try std.testing.expect(image.getPixel(0, 0).?.eql(Color.transparent));
}

test "floodFill replaces contiguous region" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 5, 5);
    defer image.deinit();

    image.fill(Color.white);
    // draw a barrier
    drawLine(&image, 2, 0, 2, 4, Color.black);

    // flood fill left side
    try floodFill(&image, 0, 0, Color.red, allocator);
    try std.testing.expect(image.getPixel(0, 0).?.eql(Color.red));
    try std.testing.expect(image.getPixel(1, 1).?.eql(Color.red));
    // right side should remain white
    try std.testing.expect(image.getPixel(3, 3).?.eql(Color.white));
}

test "floodFill same color is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 3, 3);
    defer image.deinit();

    image.fill(Color.red);
    try floodFill(&image, 1, 1, Color.red, allocator);
    try std.testing.expect(image.getPixel(1, 1).?.eql(Color.red));
}

test "drawEllipse sets pixels on axes" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 30, 30);
    defer image.deinit();

    drawEllipse(&image, 15, 15, 10, 5, Color.red);
    // ends of major axis (horizontal)
    try std.testing.expect(image.getPixel(25, 15).?.eql(Color.red));
    try std.testing.expect(image.getPixel(5, 15).?.eql(Color.red));
    // ends of minor axis (vertical)
    try std.testing.expect(image.getPixel(15, 20).?.eql(Color.red));
    try std.testing.expect(image.getPixel(15, 10).?.eql(Color.red));
}
