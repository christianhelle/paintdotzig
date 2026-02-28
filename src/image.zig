const std = @import("std");

/// RGBA color with 8-bit channels.
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255 };

    /// Pack into a single u32 (ABGR layout for little-endian framebuffers).
    pub fn toU32(self: Color) u32 {
        return @as(u32, self.a) << 24 |
            @as(u32, self.b) << 16 |
            @as(u32, self.g) << 8 |
            @as(u32, self.r);
    }

    /// Unpack from u32 (ABGR layout).
    pub fn fromU32(v: u32) Color {
        return .{
            .r = @truncate(v),
            .g = @truncate(v >> 8),
            .b = @truncate(v >> 16),
            .a = @truncate(v >> 24),
        };
    }

    /// Alpha-blend `src` over `dst` using src-over compositing.
    pub fn blend(dst: Color, src: Color) Color {
        if (src.a == 255) return src;
        if (src.a == 0) return dst;

        const sa: u16 = src.a;
        const inv_sa: u16 = 255 - sa;

        return .{
            .r = @truncate((@as(u16, src.r) * sa + @as(u16, dst.r) * inv_sa) / 255),
            .g = @truncate((@as(u16, src.g) * sa + @as(u16, dst.g) * inv_sa) / 255),
            .b = @truncate((@as(u16, src.b) * sa + @as(u16, dst.b) * inv_sa) / 255),
            .a = @truncate(sa + (@as(u16, dst.a) * inv_sa) / 255),
        };
    }

    pub fn eql(a: Color, b: Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }
};

/// A 2D bitmap image stored as a flat RGBA pixel buffer.
pub const Image = struct {
    width: u32,
    height: u32,
    pixels: []Color,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        const len = @as(usize, width) * @as(usize, height);
        const pixels = try allocator.alloc(Color, len);
        @memset(pixels, Color.transparent);
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

    /// Get pixel at (x, y). Returns null if out of bounds.
    pub fn getPixel(self: *const Image, x: i32, y: i32) ?Color {
        if (x < 0 or y < 0) return null;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return null;
        return self.pixels[@as(usize, uy) * @as(usize, self.width) + @as(usize, ux)];
    }

    /// Set pixel at (x, y). No-op if out of bounds.
    pub fn setPixel(self: *Image, x: i32, y: i32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;
        self.pixels[@as(usize, uy) * @as(usize, self.width) + @as(usize, ux)] = color;
    }

    /// Alpha-blend a color onto the pixel at (x, y).
    pub fn blendPixel(self: *Image, x: i32, y: i32, color: Color) void {
        if (self.getPixel(x, y)) |dst| {
            self.setPixel(x, y, Color.blend(dst, color));
        }
    }

    /// Fill the entire image with a solid color.
    pub fn fill(self: *Image, color: Color) void {
        @memset(self.pixels, color);
    }

    /// Fill a rectangular region with a solid color.
    pub fn fillRect(self: *Image, rx: i32, ry: i32, rw: u32, rh: u32, color: Color) void {
        const x0: i32 = @max(0, rx);
        const y0: i32 = @max(0, ry);
        const x1: i32 = @min(@as(i32, @intCast(self.width)), rx + @as(i32, @intCast(rw)));
        const y1: i32 = @min(@as(i32, @intCast(self.height)), ry + @as(i32, @intCast(rh)));

        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                self.blendPixel(x, y, color);
            }
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Color.toU32 and fromU32 roundtrip" {
    const c = Color{ .r = 10, .g = 20, .b = 30, .a = 40 };
    const val = c.toU32();
    const unpacked = Color.fromU32(val);
    try std.testing.expect(c.eql(unpacked));
}

test "Color named constants" {
    try std.testing.expectEqual(@as(u8, 0), Color.black.r);
    try std.testing.expectEqual(@as(u8, 255), Color.white.r);
    try std.testing.expectEqual(@as(u8, 0), Color.transparent.a);
}

test "Color.blend fully opaque src replaces dst" {
    const dst = Color.red;
    const src = Color.blue;
    const result = Color.blend(dst, src);
    try std.testing.expect(result.eql(Color.blue));
}

test "Color.blend fully transparent src keeps dst" {
    const dst = Color.green;
    const src = Color{ .r = 255, .g = 0, .b = 0, .a = 0 };
    const result = Color.blend(dst, src);
    try std.testing.expect(result.eql(Color.green));
}

test "Color.blend partial alpha" {
    const dst = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const src = Color{ .r = 200, .g = 100, .b = 50, .a = 128 };
    const result = Color.blend(dst, src);
    // src contributes ~50%, dst contributes ~50%
    try std.testing.expect(result.r > 80 and result.r < 120);
    try std.testing.expect(result.g > 30 and result.g < 70);
}

test "Image.init creates transparent image" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    try std.testing.expectEqual(@as(u32, 4), img.width);
    try std.testing.expectEqual(@as(u32, 4), img.height);
    try std.testing.expect(img.getPixel(0, 0).?.eql(Color.transparent));
}

test "Image.setPixel and getPixel" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 8, 8);
    defer img.deinit();

    img.setPixel(3, 5, Color.red);
    try std.testing.expect(img.getPixel(3, 5).?.eql(Color.red));
}

test "Image.setPixel out of bounds is no-op" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    img.setPixel(-1, 0, Color.red);
    img.setPixel(0, -1, Color.red);
    img.setPixel(4, 0, Color.red);
    img.setPixel(0, 4, Color.red);
    // no crash
}

test "Image.getPixel out of bounds returns null" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    try std.testing.expect(img.getPixel(-1, 0) == null);
    try std.testing.expect(img.getPixel(4, 0) == null);
}

test "Image.fill sets all pixels" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 2, 2);
    defer img.deinit();

    img.fill(Color.blue);
    for (img.pixels) |p| {
        try std.testing.expect(p.eql(Color.blue));
    }
}

test "Image.fillRect clips to bounds" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    img.fillRect(-1, -1, 3, 3, Color.red);
    // (0,0) and (1,1) should be red, (2,2) should be transparent
    try std.testing.expect(img.getPixel(0, 0).?.eql(Color.red));
    try std.testing.expect(img.getPixel(1, 1).?.eql(Color.red));
    try std.testing.expect(img.getPixel(2, 2).?.eql(Color.transparent));
}

test "Image.clone produces independent copy" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    img.setPixel(1, 1, Color.green);
    var copy = try img.clone();
    defer copy.deinit();

    try std.testing.expect(copy.getPixel(1, 1).?.eql(Color.green));
    copy.setPixel(1, 1, Color.red);
    try std.testing.expect(img.getPixel(1, 1).?.eql(Color.green));
}

test "Image.blendPixel composites correctly" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 2, 2);
    defer img.deinit();

    img.setPixel(0, 0, Color.white);
    img.blendPixel(0, 0, Color{ .r = 255, .g = 0, .b = 0, .a = 128 });
    const result = img.getPixel(0, 0).?;
    try std.testing.expect(result.r > 100);
    try std.testing.expect(result.g < 155);
}
