const std = @import("std");
const testing = std.testing;
const Color = @import("color.zig").Color;

/// A 2D image stored as a flat array of RGBA pixels
pub const Image = struct {
    width: u32,
    height: u32,
    pixels: []Color,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        const size = @as(usize, width) * @as(usize, height);
        const pixels = try allocator.alloc(Color, size);
        @memset(pixels, Color.transparent);
        return .{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn initWithColor(allocator: std.mem.Allocator, width: u32, height: u32, color: Color) !Image {
        const size = @as(usize, width) * @as(usize, height);
        const pixels = try allocator.alloc(Color, size);
        @memset(pixels, color);
        return .{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.pixels);
        self.* = undefined;
    }

    pub fn clone(self: *const Image) !Image {
        const pixels = try self.allocator.alloc(Color, self.pixels.len);
        @memcpy(pixels, self.pixels);
        return .{
            .width = self.width,
            .height = self.height,
            .pixels = pixels,
            .allocator = self.allocator,
        };
    }

    /// Get pixel index from x, y coordinates
    fn index(self: *const Image, x: u32, y: u32) ?usize {
        if (x >= self.width or y >= self.height) return null;
        return @as(usize, y) * @as(usize, self.width) + @as(usize, x);
    }

    pub fn getPixel(self: *const Image, x: u32, y: u32) ?Color {
        const idx = self.index(x, y) orelse return null;
        return self.pixels[idx];
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, color: Color) void {
        const idx = self.index(x, y) orelse return;
        self.pixels[idx] = color;
    }

    /// Set pixel with alpha blending
    pub fn blendPixel(self: *Image, x: u32, y: u32, color: Color) void {
        const idx = self.index(x, y) orelse return;
        self.pixels[idx] = color.blendOver(self.pixels[idx]);
    }

    /// Fill entire image with a color
    pub fn fill(self: *Image, color: Color) void {
        @memset(self.pixels, color);
    }

    /// Fill a rectangular region
    pub fn fillRect(self: *Image, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        const x_end = @min(x + w, self.width);
        const y_end = @min(y + h, self.height);
        var cy = y;
        while (cy < y_end) : (cy += 1) {
            var cx = x;
            while (cx < x_end) : (cx += 1) {
                self.setPixel(cx, cy, color);
            }
        }
    }

    /// Draw a horizontal line
    pub fn drawHLine(self: *Image, x: u32, y: u32, length: u32, color: Color) void {
        if (y >= self.height) return;
        const x_end = @min(x + length, self.width);
        var cx = x;
        while (cx < x_end) : (cx += 1) {
            self.setPixel(cx, y, color);
        }
    }

    /// Draw a vertical line
    pub fn drawVLine(self: *Image, x: u32, y: u32, length: u32, color: Color) void {
        if (x >= self.width) return;
        const y_end = @min(y + length, self.height);
        var cy = y;
        while (cy < y_end) : (cy += 1) {
            self.setPixel(x, cy, color);
        }
    }

    /// Copy a region from another image (blit)
    pub fn blit(self: *Image, src: *const Image, dst_x: i32, dst_y: i32) void {
        var sy: u32 = 0;
        while (sy < src.height) : (sy += 1) {
            const dy = dst_y + @as(i32, @intCast(sy));
            if (dy < 0 or dy >= @as(i32, @intCast(self.height))) continue;
            var sx: u32 = 0;
            while (sx < src.width) : (sx += 1) {
                const dx = dst_x + @as(i32, @intCast(sx));
                if (dx < 0 or dx >= @as(i32, @intCast(self.width))) continue;
                const color = src.getPixel(sx, sy) orelse continue;
                self.blendPixel(@intCast(dx), @intCast(dy), color);
            }
        }
    }

    /// Get raw pixel data as bytes (for file I/O)
    pub fn asBytes(self: *const Image) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.pixels.ptr);
        return ptr[0 .. self.pixels.len * 4];
    }

    /// Flip image horizontally
    pub fn flipHorizontal(self: *Image) void {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width / 2) : (x += 1) {
                const left_idx = self.index(x, y).?;
                const right_idx = self.index(self.width - 1 - x, y).?;
                const tmp = self.pixels[left_idx];
                self.pixels[left_idx] = self.pixels[right_idx];
                self.pixels[right_idx] = tmp;
            }
        }
    }

    /// Flip image vertically
    pub fn flipVertical(self: *Image) void {
        var y: u32 = 0;
        while (y < self.height / 2) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const top_idx = self.index(x, y).?;
                const bottom_idx = self.index(x, self.height - 1 - y).?;
                const tmp = self.pixels[top_idx];
                self.pixels[top_idx] = self.pixels[bottom_idx];
                self.pixels[bottom_idx] = tmp;
            }
        }
    }

    /// Crop image to a rectangular region, returns a new image
    pub fn crop(self: *const Image, x: u32, y: u32, w: u32, h: u32) !Image {
        const cx = @min(x, self.width);
        const cy = @min(y, self.height);
        const cw = @min(w, self.width - cx);
        const ch = @min(h, self.height - cy);

        var result = try Image.init(self.allocator, cw, ch);
        var dy: u32 = 0;
        while (dy < ch) : (dy += 1) {
            var dx: u32 = 0;
            while (dx < cw) : (dx += 1) {
                const color = self.getPixel(cx + dx, cy + dy) orelse Color.transparent;
                result.setPixel(dx, dy, color);
            }
        }
        return result;
    }

    /// Resize image using nearest-neighbor interpolation
    pub fn resize(self: *const Image, new_width: u32, new_height: u32) !Image {
        var result = try Image.init(self.allocator, new_width, new_height);
        var y: u32 = 0;
        while (y < new_height) : (y += 1) {
            var x: u32 = 0;
            while (x < new_width) : (x += 1) {
                const src_x: u32 = @intFromFloat(@as(f64, @floatFromInt(x)) * @as(f64, @floatFromInt(self.width)) / @as(f64, @floatFromInt(new_width)));
                const src_y: u32 = @intFromFloat(@as(f64, @floatFromInt(y)) * @as(f64, @floatFromInt(self.height)) / @as(f64, @floatFromInt(new_height)));
                const color = self.getPixel(@min(src_x, self.width - 1), @min(src_y, self.height - 1)) orelse Color.transparent;
                result.setPixel(x, y, color);
            }
        }
        return result;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Image.init creates transparent image" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    try testing.expectEqual(@as(u32, 10), img.width);
    try testing.expectEqual(@as(u32, 10), img.height);
    try testing.expectEqual(@as(usize, 100), img.pixels.len);

    const pixel = img.getPixel(0, 0).?;
    try testing.expect(pixel.eql(Color.transparent));
}

test "Image.initWithColor" {
    var img = try Image.initWithColor(testing.allocator, 5, 5, Color.red);
    defer img.deinit();

    const pixel = img.getPixel(2, 2).?;
    try testing.expect(pixel.eql(Color.red));
}

test "Image.setPixel and getPixel" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.setPixel(5, 5, Color.blue);
    const pixel = img.getPixel(5, 5).?;
    try testing.expect(pixel.eql(Color.blue));
}

test "Image.getPixel out of bounds returns null" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    try testing.expect(img.getPixel(10, 0) == null);
    try testing.expect(img.getPixel(0, 10) == null);
    try testing.expect(img.getPixel(100, 100) == null);
}

test "Image.setPixel out of bounds is no-op" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.setPixel(100, 100, Color.red); // should not crash
}

test "Image.fill" {
    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();

    img.fill(Color.green);
    for (img.pixels) |p| {
        try testing.expect(p.eql(Color.green));
    }
}

test "Image.fillRect" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.fillRect(2, 2, 3, 3, Color.red);
    try testing.expect(img.getPixel(2, 2).?.eql(Color.red));
    try testing.expect(img.getPixel(4, 4).?.eql(Color.red));
    try testing.expect(img.getPixel(1, 1).?.eql(Color.transparent));
    try testing.expect(img.getPixel(5, 5).?.eql(Color.transparent));
}

test "Image.fillRect clamps to bounds" {
    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();
    img.fillRect(3, 3, 10, 10, Color.red); // extends past image
    try testing.expect(img.getPixel(4, 4).?.eql(Color.red));
}

test "Image.drawHLine" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.drawHLine(2, 5, 4, Color.blue);
    try testing.expect(img.getPixel(2, 5).?.eql(Color.blue));
    try testing.expect(img.getPixel(5, 5).?.eql(Color.blue));
    try testing.expect(img.getPixel(1, 5).?.eql(Color.transparent));
    try testing.expect(img.getPixel(6, 5).?.eql(Color.transparent));
}

test "Image.drawVLine" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.drawVLine(3, 1, 4, Color.green);
    try testing.expect(img.getPixel(3, 1).?.eql(Color.green));
    try testing.expect(img.getPixel(3, 4).?.eql(Color.green));
    try testing.expect(img.getPixel(3, 0).?.eql(Color.transparent));
}

test "Image.clone" {
    var img = try Image.initWithColor(testing.allocator, 5, 5, Color.red);
    defer img.deinit();

    var cloned = try img.clone();
    defer cloned.deinit();

    try testing.expectEqual(img.width, cloned.width);
    try testing.expectEqual(img.height, cloned.height);
    try testing.expect(cloned.getPixel(0, 0).?.eql(Color.red));

    // Modify original, clone should be independent
    img.setPixel(0, 0, Color.blue);
    try testing.expect(cloned.getPixel(0, 0).?.eql(Color.red));
}

test "Image.blit" {
    var dst = try Image.init(testing.allocator, 10, 10);
    defer dst.deinit();

    var src = try Image.initWithColor(testing.allocator, 3, 3, Color.red);
    defer src.deinit();

    dst.blit(&src, 2, 2);
    try testing.expect(dst.getPixel(2, 2).?.eql(Color.red));
    try testing.expect(dst.getPixel(4, 4).?.eql(Color.red));
    try testing.expect(dst.getPixel(1, 1).?.eql(Color.transparent));
}

test "Image.blit with negative offset" {
    var dst = try Image.initWithColor(testing.allocator, 5, 5, Color.white);
    defer dst.deinit();

    var src = try Image.initWithColor(testing.allocator, 3, 3, Color.red);
    defer src.deinit();

    dst.blit(&src, -1, -1);
    // Only the bottom-right 2x2 of src should appear at (0,0)
    try testing.expect(dst.getPixel(0, 0).?.eql(Color.red));
    try testing.expect(dst.getPixel(1, 1).?.eql(Color.red));
}

test "Image.flipHorizontal" {
    var img = try Image.init(testing.allocator, 4, 1);
    defer img.deinit();

    img.setPixel(0, 0, Color.red);
    img.setPixel(3, 0, Color.blue);

    img.flipHorizontal();
    try testing.expect(img.getPixel(0, 0).?.eql(Color.blue));
    try testing.expect(img.getPixel(3, 0).?.eql(Color.red));
}

test "Image.flipVertical" {
    var img = try Image.init(testing.allocator, 1, 4);
    defer img.deinit();

    img.setPixel(0, 0, Color.red);
    img.setPixel(0, 3, Color.blue);

    img.flipVertical();
    try testing.expect(img.getPixel(0, 0).?.eql(Color.blue));
    try testing.expect(img.getPixel(0, 3).?.eql(Color.red));
}

test "Image.crop" {
    var img = try Image.init(testing.allocator, 10, 10);
    defer img.deinit();

    img.fillRect(3, 3, 4, 4, Color.red);
    var cropped = try img.crop(3, 3, 4, 4);
    defer cropped.deinit();

    try testing.expectEqual(@as(u32, 4), cropped.width);
    try testing.expectEqual(@as(u32, 4), cropped.height);
    try testing.expect(cropped.getPixel(0, 0).?.eql(Color.red));
    try testing.expect(cropped.getPixel(3, 3).?.eql(Color.red));
}

test "Image.resize" {
    var img = try Image.initWithColor(testing.allocator, 4, 4, Color.red);
    defer img.deinit();

    var resized = try img.resize(8, 8);
    defer resized.deinit();

    try testing.expectEqual(@as(u32, 8), resized.width);
    try testing.expectEqual(@as(u32, 8), resized.height);
    try testing.expect(resized.getPixel(0, 0).?.eql(Color.red));
    try testing.expect(resized.getPixel(7, 7).?.eql(Color.red));
}

test "Image.resize downscale" {
    var img = try Image.initWithColor(testing.allocator, 8, 8, Color.blue);
    defer img.deinit();

    var resized = try img.resize(2, 2);
    defer resized.deinit();

    try testing.expectEqual(@as(u32, 2), resized.width);
    try testing.expect(resized.getPixel(0, 0).?.eql(Color.blue));
}

test "Image.asBytes length" {
    var img = try Image.init(testing.allocator, 3, 3);
    defer img.deinit();

    const bytes = img.asBytes();
    try testing.expectEqual(@as(usize, 3 * 3 * 4), bytes.len);
}

test "Image.blendPixel" {
    var img = try Image.initWithColor(testing.allocator, 1, 1, Color.blue);
    defer img.deinit();

    img.blendPixel(0, 0, Color.init(255, 0, 0, 128));
    const result = img.getPixel(0, 0).?;
    try testing.expect(result.r > 100);
    try testing.expect(result.b > 100);
}
