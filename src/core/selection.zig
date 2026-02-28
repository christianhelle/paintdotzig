const std = @import("std");
const testing = std.testing;

/// A selection mask - each pixel has a value 0-255 indicating selection strength
pub const Selection = struct {
    width: u32,
    height: u32,
    mask: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Selection {
        const size = @as(usize, width) * @as(usize, height);
        const mask = try allocator.alloc(u8, size);
        @memset(mask, 0);
        return .{
            .width = width,
            .height = height,
            .mask = mask,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Selection) void {
        self.allocator.free(self.mask);
        self.* = undefined;
    }

    pub fn clone(self: *const Selection) !Selection {
        const mask = try self.allocator.alloc(u8, self.mask.len);
        @memcpy(mask, self.mask);
        return .{
            .width = self.width,
            .height = self.height,
            .mask = mask,
            .allocator = self.allocator,
        };
    }

    fn index(self: *const Selection, x: u32, y: u32) ?usize {
        if (x >= self.width or y >= self.height) return null;
        return @as(usize, y) * @as(usize, self.width) + @as(usize, x);
    }

    pub fn getValue(self: *const Selection, x: u32, y: u32) u8 {
        const idx = self.index(x, y) orelse return 0;
        return self.mask[idx];
    }

    pub fn setValue(self: *Selection, x: u32, y: u32, value: u8) void {
        const idx = self.index(x, y) orelse return;
        self.mask[idx] = value;
    }

    /// Select all pixels
    pub fn selectAll(self: *Selection) void {
        @memset(self.mask, 255);
    }

    /// Clear selection
    pub fn selectNone(self: *Selection) void {
        @memset(self.mask, 0);
    }

    /// Invert selection
    pub fn invert(self: *Selection) void {
        for (self.mask) |*v| {
            v.* = 255 - v.*;
        }
    }

    /// Select a rectangular region
    pub fn selectRect(self: *Selection, x: u32, y: u32, w: u32, h: u32) void {
        self.selectNone();
        const x_end = @min(x + w, self.width);
        const y_end = @min(y + h, self.height);
        var cy = y;
        while (cy < y_end) : (cy += 1) {
            var cx = x;
            while (cx < x_end) : (cx += 1) {
                self.setValue(cx, cy, 255);
            }
        }
    }

    /// Select an elliptical region
    pub fn selectEllipse(self: *Selection, cx: u32, cy: u32, rx: u32, ry: u32) void {
        self.selectNone();
        const center_x: f32 = @floatFromInt(cx);
        const center_y: f32 = @floatFromInt(cy);
        const radius_x: f32 = @floatFromInt(rx);
        const radius_y: f32 = @floatFromInt(ry);

        const start_y = if (cy >= ry) cy - ry else 0;
        const end_y = @min(cy + ry + 1, self.height);
        const start_x = if (cx >= rx) cx - rx else 0;
        const end_x = @min(cx + rx + 1, self.width);

        var py = start_y;
        while (py < end_y) : (py += 1) {
            var px = start_x;
            while (px < end_x) : (px += 1) {
                const dx = (@as(f32, @floatFromInt(px)) - center_x) / radius_x;
                const dy = (@as(f32, @floatFromInt(py)) - center_y) / radius_y;
                if (dx * dx + dy * dy <= 1.0) {
                    self.setValue(px, py, 255);
                }
            }
        }
    }

    /// Union with another selection
    pub fn combine(self: *Selection, other: *const Selection) void {
        const len = @min(self.mask.len, other.mask.len);
        for (0..len) |i| {
            self.mask[i] = @max(self.mask[i], other.mask[i]);
        }
    }

    /// Intersect with another selection
    pub fn intersect(self: *Selection, other: *const Selection) void {
        const len = @min(self.mask.len, other.mask.len);
        for (0..len) |i| {
            self.mask[i] = @min(self.mask[i], other.mask[i]);
        }
    }

    /// Subtract another selection
    pub fn subtract(self: *Selection, other: *const Selection) void {
        const len = @min(self.mask.len, other.mask.len);
        for (0..len) |i| {
            self.mask[i] = if (other.mask[i] >= self.mask[i]) 0 else self.mask[i] - other.mask[i];
        }
    }

    /// Check if anything is selected
    pub fn hasSelection(self: *const Selection) bool {
        for (self.mask) |v| {
            if (v > 0) return true;
        }
        return false;
    }

    /// Get bounding box of selection (returns null if empty)
    pub fn getBounds(self: *const Selection) ?struct { x: u32, y: u32, w: u32, h: u32 } {
        var min_x: u32 = self.width;
        var min_y: u32 = self.height;
        var max_x: u32 = 0;
        var max_y: u32 = 0;

        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                if (self.getValue(x, y) > 0) {
                    min_x = @min(min_x, x);
                    min_y = @min(min_y, y);
                    max_x = @max(max_x, x);
                    max_y = @max(max_y, y);
                }
            }
        }

        if (min_x > max_x) return null;
        return .{ .x = min_x, .y = min_y, .w = max_x - min_x + 1, .h = max_y - min_y + 1 };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Selection.init creates empty selection" {
    var sel = try Selection.init(testing.allocator, 10, 10);
    defer sel.deinit();

    try testing.expect(!sel.hasSelection());
    try testing.expectEqual(@as(u8, 0), sel.getValue(0, 0));
}

test "Selection.selectAll and selectNone" {
    var sel = try Selection.init(testing.allocator, 5, 5);
    defer sel.deinit();

    sel.selectAll();
    try testing.expect(sel.hasSelection());
    try testing.expectEqual(@as(u8, 255), sel.getValue(0, 0));

    sel.selectNone();
    try testing.expect(!sel.hasSelection());
}

test "Selection.setValue and getValue" {
    var sel = try Selection.init(testing.allocator, 10, 10);
    defer sel.deinit();

    sel.setValue(5, 5, 128);
    try testing.expectEqual(@as(u8, 128), sel.getValue(5, 5));
    try testing.expectEqual(@as(u8, 0), sel.getValue(0, 0));
}

test "Selection.getValue out of bounds" {
    var sel = try Selection.init(testing.allocator, 5, 5);
    defer sel.deinit();

    try testing.expectEqual(@as(u8, 0), sel.getValue(10, 10));
}

test "Selection.invert" {
    var sel = try Selection.init(testing.allocator, 5, 5);
    defer sel.deinit();

    sel.setValue(0, 0, 200);
    sel.invert();
    try testing.expectEqual(@as(u8, 55), sel.getValue(0, 0));
    try testing.expectEqual(@as(u8, 255), sel.getValue(1, 1));
}

test "Selection.selectRect" {
    var sel = try Selection.init(testing.allocator, 10, 10);
    defer sel.deinit();

    sel.selectRect(2, 2, 3, 3);
    try testing.expectEqual(@as(u8, 255), sel.getValue(2, 2));
    try testing.expectEqual(@as(u8, 255), sel.getValue(4, 4));
    try testing.expectEqual(@as(u8, 0), sel.getValue(1, 1));
    try testing.expectEqual(@as(u8, 0), sel.getValue(5, 5));
}

test "Selection.selectEllipse" {
    var sel = try Selection.init(testing.allocator, 20, 20);
    defer sel.deinit();

    sel.selectEllipse(10, 10, 5, 5);
    try testing.expectEqual(@as(u8, 255), sel.getValue(10, 10)); // center
    try testing.expectEqual(@as(u8, 0), sel.getValue(0, 0)); // outside
}

test "Selection.combine" {
    var a = try Selection.init(testing.allocator, 10, 10);
    defer a.deinit();
    var b = try Selection.init(testing.allocator, 10, 10);
    defer b.deinit();

    a.selectRect(0, 0, 5, 5);
    b.selectRect(3, 3, 5, 5);
    a.combine(&b);

    try testing.expectEqual(@as(u8, 255), a.getValue(0, 0));
    try testing.expectEqual(@as(u8, 255), a.getValue(4, 4));
    try testing.expectEqual(@as(u8, 255), a.getValue(7, 7));
}

test "Selection.intersect" {
    var a = try Selection.init(testing.allocator, 10, 10);
    defer a.deinit();
    var b = try Selection.init(testing.allocator, 10, 10);
    defer b.deinit();

    a.selectRect(0, 0, 6, 6);
    b.selectRect(3, 3, 6, 6);
    a.intersect(&b);

    try testing.expectEqual(@as(u8, 0), a.getValue(0, 0));
    try testing.expectEqual(@as(u8, 255), a.getValue(4, 4));
    try testing.expectEqual(@as(u8, 0), a.getValue(7, 7));
}

test "Selection.subtract" {
    var a = try Selection.init(testing.allocator, 10, 10);
    defer a.deinit();
    var b = try Selection.init(testing.allocator, 10, 10);
    defer b.deinit();

    a.selectRect(0, 0, 8, 8);
    b.selectRect(4, 4, 4, 4);
    a.subtract(&b);

    try testing.expectEqual(@as(u8, 255), a.getValue(0, 0));
    try testing.expectEqual(@as(u8, 0), a.getValue(5, 5));
}

test "Selection.getBounds" {
    var sel = try Selection.init(testing.allocator, 10, 10);
    defer sel.deinit();

    try testing.expect(sel.getBounds() == null);

    sel.selectRect(2, 3, 4, 5);
    const bounds = sel.getBounds().?;
    try testing.expectEqual(@as(u32, 2), bounds.x);
    try testing.expectEqual(@as(u32, 3), bounds.y);
    try testing.expectEqual(@as(u32, 4), bounds.w);
    try testing.expectEqual(@as(u32, 5), bounds.h);
}

test "Selection.clone" {
    var sel = try Selection.init(testing.allocator, 5, 5);
    defer sel.deinit();

    sel.selectRect(1, 1, 3, 3);

    var cloned = try sel.clone();
    defer cloned.deinit();

    try testing.expectEqual(@as(u8, 255), cloned.getValue(2, 2));
    try testing.expectEqual(@as(u8, 0), cloned.getValue(0, 0));
}
