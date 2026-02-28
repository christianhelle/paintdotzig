const std = @import("std");
const testing = std.testing;
const Color = @import("../core/color.zig").Color;
const Image = @import("../core/image.zig").Image;

/// Available tool types
pub const ToolType = enum {
    brush,
    eraser,
    fill,
    picker,
    select_rect,
    select_ellipse,
    move,
    zoom,
    shapes,
    text,
    gradient,
    wand,
    clone,
    recolor,
};

/// Brush parameters shared by drawing tools
pub const BrushParams = struct {
    size: u32 = 5,
    hardness: f32 = 1.0, // 0.0 (soft) to 1.0 (hard)
    opacity: f32 = 1.0,
    color: Color = Color.black,
};

/// Draw a filled circle (brush stamp) on an image
pub fn drawBrushStamp(img: *Image, cx: i32, cy: i32, params: BrushParams) void {
    const radius: i32 = @intCast(params.size / 2);
    const radius_f: f32 = @floatFromInt(radius);

    var dy: i32 = -radius;
    while (dy <= radius) : (dy += 1) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += 1) {
            const dist = @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));
            if (dist > radius_f) continue;

            // Apply hardness falloff
            var alpha: f32 = params.opacity;
            if (params.hardness < 1.0) {
                const edge = 1.0 - (dist / radius_f);
                alpha *= @min(edge / (1.0 - params.hardness), 1.0);
            }

            const px = cx + dx;
            const py = cy + dy;
            if (px < 0 or py < 0) continue;

            const color = Color.init(params.color.r, params.color.g, params.color.b, @intFromFloat(alpha * 255.0));
            img.blendPixel(@intCast(px), @intCast(py), color);
        }
    }
}

/// Draw a line using Bresenham's algorithm
pub fn drawLine(img: *Image, x0: i32, y0: i32, x1: i32, y1: i32, params: BrushParams) void {
    var x = x0;
    var y = y0;
    const dx = @as(i32, if (x1 > x0) 1 else -1);
    const dy = @as(i32, if (y1 > y0) 1 else -1);
    const abs_dx = @as(i32, @intCast(@abs(x1 - x0)));
    const abs_dy = @as(i32, @intCast(@abs(y1 - y0)));

    if (abs_dx >= abs_dy) {
        var err: i32 = @divTrunc(abs_dx, 2);
        var i: i32 = 0;
        while (i <= abs_dx) : (i += 1) {
            drawBrushStamp(img, x, y, params);
            err -= abs_dy;
            if (err < 0) {
                y += dy;
                err += abs_dx;
            }
            x += dx;
        }
    } else {
        var err: i32 = @divTrunc(abs_dy, 2);
        var i: i32 = 0;
        while (i <= abs_dy) : (i += 1) {
            drawBrushStamp(img, x, y, params);
            err -= abs_dx;
            if (err < 0) {
                x += dx;
                err += abs_dy;
            }
            y += dy;
        }
    }
}

/// Flood fill from a starting point
pub fn floodFill(img: *Image, start_x: u32, start_y: u32, fill_color: Color, tolerance: u8) !void {
    const target = img.getPixel(start_x, start_y) orelse return;
    if (target.eql(fill_color)) return;

    var queue = std.ArrayList(struct { x: u32, y: u32 }).empty;
    defer queue.deinit(img.allocator);

    try queue.append(img.allocator, .{ .x = start_x, .y = start_y });

    while (queue.items.len > 0) {
        const pt = queue.pop() orelse break;
        const current = img.getPixel(pt.x, pt.y) orelse continue;

        if (!colorMatch(current, target, tolerance)) continue;

        img.setPixel(pt.x, pt.y, fill_color);

        if (pt.x > 0) try queue.append(img.allocator, .{ .x = pt.x - 1, .y = pt.y });
        if (pt.x < img.width - 1) try queue.append(img.allocator, .{ .x = pt.x + 1, .y = pt.y });
        if (pt.y > 0) try queue.append(img.allocator, .{ .x = pt.x, .y = pt.y - 1 });
        if (pt.y < img.height - 1) try queue.append(img.allocator, .{ .x = pt.x, .y = pt.y + 1 });
    }
}

/// Check if two colors match within tolerance
pub fn colorMatch(a: Color, b: Color, tolerance: u8) bool {
    const dr = @as(i16, @intCast(a.r)) - @as(i16, @intCast(b.r));
    const dg = @as(i16, @intCast(a.g)) - @as(i16, @intCast(b.g));
    const db = @as(i16, @intCast(a.b)) - @as(i16, @intCast(b.b));
    const da = @as(i16, @intCast(a.a)) - @as(i16, @intCast(b.a));
    const dist = @abs(dr) + @abs(dg) + @abs(db) + @abs(da);
    return dist <= @as(i16, tolerance) * 4;
}

/// Draw a rectangle outline
pub fn drawRect(img: *Image, x: u32, y: u32, w: u32, h: u32, color: Color, thickness: u32) void {
    img.drawHLine(x, y, w, color);
    img.drawHLine(x, y + h - 1, w, color);
    img.drawVLine(x, y, h, color);
    img.drawVLine(x + w - 1, y, h, color);

    // Additional thickness
    var t: u32 = 1;
    while (t < thickness) : (t += 1) {
        if (y + t < y + h) img.drawHLine(x, y + t, w, color);
        if (y + h - 1 >= t) img.drawHLine(x, y + h - 1 - t, w, color);
        if (x + t < x + w) img.drawVLine(x + t, y, h, color);
        if (x + w - 1 >= t) img.drawVLine(x + w - 1 - t, y, h, color);
    }
}

/// Draw a filled rectangle
pub fn drawFilledRect(img: *Image, x: u32, y: u32, w: u32, h: u32, color: Color) void {
    img.fillRect(x, y, w, h, color);
}

/// Draw an ellipse outline
pub fn drawEllipse(img: *Image, cx: i32, cy: i32, rx: u32, ry: u32, color: Color) void {
    const a: i32 = @intCast(rx);
    const b: i32 = @intCast(ry);
    var x: i32 = 0;
    var y: i32 = b;

    // Region 1
    var d1 = b * b - a * a * b + @divTrunc(a * a, 4);
    while (2 * b * b * x <= 2 * a * a * y) {
        setPixelSafe(img, cx + x, cy + y, color);
        setPixelSafe(img, cx - x, cy + y, color);
        setPixelSafe(img, cx + x, cy - y, color);
        setPixelSafe(img, cx - x, cy - y, color);

        if (d1 < 0) {
            d1 += 2 * b * b * x + 3 * b * b;
        } else {
            d1 += 2 * b * b * x - 2 * a * a * y + 2 * a * a + 3 * b * b;
            y -= 1;
        }
        x += 1;
    }

    // Region 2
    var d2 = b * b * (x * x + x) + a * a * (y * y - 2 * y + 1) - a * a * b * b;
    while (y >= 0) {
        setPixelSafe(img, cx + x, cy + y, color);
        setPixelSafe(img, cx - x, cy + y, color);
        setPixelSafe(img, cx + x, cy - y, color);
        setPixelSafe(img, cx - x, cy - y, color);

        if (d2 > 0) {
            d2 += -2 * a * a * y + 3 * a * a;
        } else {
            d2 += 2 * b * b * x - 2 * a * a * y + 2 * b * b + 3 * a * a;
            x += 1;
        }
        y -= 1;
    }
}

fn setPixelSafe(img: *Image, x: i32, y: i32, color: Color) void {
    if (x < 0 or y < 0) return;
    if (x >= @as(i32, @intCast(img.width)) or y >= @as(i32, @intCast(img.height))) return;
    img.setPixel(@intCast(x), @intCast(y), color);
}

/// Apply linear gradient to an image region
pub fn linearGradient(img: *Image, x: u32, y: u32, w: u32, h: u32, start_color: Color, end_color: Color, horizontal: bool) void {
    const x_end = @min(x + w, img.width);
    const y_end = @min(y + h, img.height);

    var cy = y;
    while (cy < y_end) : (cy += 1) {
        var cx = x;
        while (cx < x_end) : (cx += 1) {
            const t: f32 = if (horizontal)
                @as(f32, @floatFromInt(cx - x)) / @as(f32, @floatFromInt(w))
            else
                @as(f32, @floatFromInt(cy - y)) / @as(f32, @floatFromInt(h));

            const color = start_color.lerp(end_color, t);
            img.blendPixel(cx, cy, color);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "drawBrushStamp" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawBrushStamp(&img, 10, 10, .{ .size = 5, .color = Color.red });
    try testing.expect(img.getPixel(10, 10).?.r == 255);
}

test "drawBrushStamp soft brush" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawBrushStamp(&img, 10, 10, .{ .size = 10, .hardness = 0.5, .color = Color.blue });
    // Center should be fully blue
    try testing.expect(img.getPixel(10, 10).?.b > 0);
}

test "drawLine horizontal" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawLine(&img, 0, 10, 19, 10, .{ .size = 1, .color = Color.red });
    try testing.expect(img.getPixel(0, 10).?.r > 0);
    try testing.expect(img.getPixel(10, 10).?.r > 0);
    try testing.expect(img.getPixel(19, 10).?.r > 0);
}

test "drawLine vertical" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawLine(&img, 10, 0, 10, 19, .{ .size = 1, .color = Color.green });
    try testing.expect(img.getPixel(10, 0).?.g > 0);
    try testing.expect(img.getPixel(10, 19).?.g > 0);
}

test "drawLine diagonal" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawLine(&img, 0, 0, 19, 19, .{ .size = 1, .color = Color.blue });
    try testing.expect(img.getPixel(0, 0).?.b > 0);
    try testing.expect(img.getPixel(10, 10).?.b > 0);
}

test "floodFill" {
    var img = try Image.initWithColor(testing.allocator, 10, 10, Color.white);
    defer img.deinit();

    // Create a border
    img.drawHLine(0, 5, 10, Color.black);

    // Fill top half
    try floodFill(&img, 5, 2, Color.red, 0);
    try testing.expect(img.getPixel(5, 2).?.eql(Color.red));
    // Bottom should remain white
    try testing.expect(img.getPixel(5, 7).?.eql(Color.white));
}

test "colorMatch exact" {
    try testing.expect(colorMatch(Color.red, Color.red, 0));
    try testing.expect(!colorMatch(Color.red, Color.blue, 0));
}

test "colorMatch with tolerance" {
    const a = Color.init(100, 100, 100, 255);
    const b = Color.init(105, 105, 105, 255);
    try testing.expect(colorMatch(a, b, 10));
    try testing.expect(!colorMatch(a, b, 1));
}

test "drawRect" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawRect(&img, 5, 5, 10, 10, Color.red, 1);
    try testing.expect(img.getPixel(5, 5).?.eql(Color.red));
    try testing.expect(img.getPixel(14, 14).?.eql(Color.red));
    try testing.expect(img.getPixel(10, 10).?.eql(Color.transparent));
}

test "drawFilledRect" {
    var img = try Image.init(testing.allocator, 20, 20);
    defer img.deinit();

    drawFilledRect(&img, 5, 5, 10, 10, Color.blue);
    try testing.expect(img.getPixel(10, 10).?.eql(Color.blue));
}

test "drawEllipse" {
    var img = try Image.init(testing.allocator, 30, 30);
    defer img.deinit();

    drawEllipse(&img, 15, 15, 10, 8, Color.green);
    // Top of ellipse
    try testing.expect(img.getPixel(15, 7).?.eql(Color.green));
}

test "linearGradient horizontal" {
    var img = try Image.init(testing.allocator, 10, 1);
    defer img.deinit();

    linearGradient(&img, 0, 0, 10, 1, Color.black, Color.white, true);
    const left = img.getPixel(0, 0).?;
    const right = img.getPixel(9, 0).?;
    try testing.expect(right.r > left.r);
}

test "linearGradient vertical" {
    var img = try Image.init(testing.allocator, 1, 10);
    defer img.deinit();

    linearGradient(&img, 0, 0, 1, 10, Color.red, Color.blue, false);
    const top = img.getPixel(0, 0).?;
    const bottom = img.getPixel(0, 9).?;
    try testing.expect(top.r > bottom.r);
    try testing.expect(bottom.b > top.b);
}
