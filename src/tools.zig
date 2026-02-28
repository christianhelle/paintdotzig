const std = @import("std");
const img = @import("image.zig");
const canvas = @import("canvas.zig");
const Color = img.Color;
const Image = img.Image;

/// Available editing tools.
pub const ToolKind = enum {
    pencil,
    brush,
    eraser,
    fill,
    line,
    rectangle,
    ellipse,
    circle,
    color_picker,
    select_rect,
};

/// Selection rectangle (screen coordinates).
pub const Selection = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: u32 = 0,
    h: u32 = 0,

    pub fn empty() Selection {
        return .{};
    }

    pub fn isEmpty(self: Selection) bool {
        return self.w == 0 or self.h == 0;
    }

    pub fn contains(self: Selection, px: i32, py: i32) bool {
        return px >= self.x and
            px < self.x + @as(i32, @intCast(self.w)) and
            py >= self.y and
            py < self.y + @as(i32, @intCast(self.h));
    }
};

/// Shared state for the active tool.
pub const ToolState = struct {
    kind: ToolKind = .pencil,
    primary_color: Color = Color.black,
    secondary_color: Color = Color.white,
    brush_size: u32 = 1,
    selection: Selection = Selection.empty(),

    /// Apply tool at a single point.
    pub fn applyAt(self: *const ToolState, image: *Image, x: i32, y: i32) void {
        switch (self.kind) {
            .pencil => image.setPixel(x, y, self.primary_color),
            .brush => canvas.fillCircle(image, x, y, self.brush_size / 2, self.primary_color),
            .eraser => canvas.fillCircleDirect(image, x, y, self.brush_size / 2, Color.transparent),
            .color_picker => {
                // Color picker is read-only — handled by the UI layer
            },
            else => {},
        }
    }

    /// Apply tool drag from (x0,y0) to (x1,y1).
    pub fn applyStroke(self: *const ToolState, image: *Image, x0: i32, y0: i32, x1: i32, y1: i32) void {
        switch (self.kind) {
            .pencil => canvas.drawLine(image, x0, y0, x1, y1, self.primary_color),
            .brush => {
                // Walk the line and stamp circles
                var cx = x0;
                var cy = y0;
                const dx: i32 = @intCast(@abs(x1 - x0));
                const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
                const sx: i32 = if (x0 < x1) 1 else -1;
                const sy: i32 = if (y0 < y1) 1 else -1;
                var err = dx + dy;
                while (true) {
                    canvas.fillCircle(image, cx, cy, self.brush_size / 2, self.primary_color);
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
            },
            .eraser => {
                var cx = x0;
                var cy = y0;
                const dx: i32 = @intCast(@abs(x1 - x0));
                const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
                const sx: i32 = if (x0 < x1) 1 else -1;
                const sy: i32 = if (y0 < y1) 1 else -1;
                var err = dx + dy;
                while (true) {
                    canvas.fillCircleDirect(image, cx, cy, self.brush_size / 2, Color.transparent);
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
            },
            .line => canvas.drawLine(image, x0, y0, x1, y1, self.primary_color),
            else => {},
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Selection.isEmpty" {
    const sel = Selection.empty();
    try std.testing.expect(sel.isEmpty());
}

test "Selection.contains" {
    const sel = Selection{ .x = 5, .y = 5, .w = 10, .h = 10 };
    try std.testing.expect(sel.contains(5, 5));
    try std.testing.expect(sel.contains(14, 14));
    try std.testing.expect(!sel.contains(15, 15));
    try std.testing.expect(!sel.contains(4, 5));
}

test "ToolState pencil applies single pixel" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    const tool = ToolState{ .kind = .pencil, .primary_color = Color.red };
    tool.applyAt(&image, 5, 5);
    try std.testing.expect(image.getPixel(5, 5).?.eql(Color.red));
}

test "ToolState brush applies filled circle" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 20, 20);
    defer image.deinit();

    const tool = ToolState{ .kind = .brush, .primary_color = Color.blue, .brush_size = 4 };
    tool.applyAt(&image, 10, 10);
    try std.testing.expect(image.getPixel(10, 10).?.eql(Color.blue));
}

test "ToolState eraser clears pixels" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    image.fill(Color.white);
    const tool = ToolState{ .kind = .eraser, .brush_size = 2 };
    tool.applyAt(&image, 5, 5);
    try std.testing.expect(image.getPixel(5, 5).?.eql(Color.transparent));
}

test "ToolState pencil stroke draws line" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    const tool = ToolState{ .kind = .pencil, .primary_color = Color.green };
    tool.applyStroke(&image, 0, 0, 9, 0);
    try std.testing.expect(image.getPixel(0, 0).?.eql(Color.green));
    try std.testing.expect(image.getPixel(9, 0).?.eql(Color.green));
}

test "ToolState line tool draws between points" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 10, 10);
    defer image.deinit();

    const tool = ToolState{ .kind = .line, .primary_color = Color.red };
    tool.applyStroke(&image, 0, 5, 9, 5);
    try std.testing.expect(image.getPixel(5, 5).?.eql(Color.red));
}

test "ToolState color_picker is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    const tool = ToolState{ .kind = .color_picker };
    tool.applyAt(&image, 2, 2);
    // should remain transparent
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.transparent));
}

test "ToolState ellipse applyAt is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    const tool = ToolState{ .kind = .ellipse };
    tool.applyAt(&image, 2, 2);
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.transparent));
}

test "ToolState ellipse applyStroke is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    const tool = ToolState{ .kind = .ellipse };
    tool.applyStroke(&image, 0, 0, 3, 3);
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.transparent));
}

test "ToolState select_rect applyAt is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    const tool = ToolState{ .kind = .select_rect };
    tool.applyAt(&image, 2, 2);
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.transparent));
}

test "ToolState select_rect applyStroke is no-op" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    const tool = ToolState{ .kind = .select_rect };
    tool.applyStroke(&image, 0, 0, 3, 3);
    try std.testing.expect(image.getPixel(2, 2).?.eql(Color.transparent));
}
