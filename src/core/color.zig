const std = @import("std");
const testing = std.testing;

/// RGBA color with 8 bits per channel
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    /// Pack color into a single u32 (RGBA order)
    pub fn toU32(self: Color) u32 {
        return @as(u32, self.r) << 24 |
            @as(u32, self.g) << 16 |
            @as(u32, self.b) << 8 |
            @as(u32, self.a);
    }

    /// Unpack a u32 (RGBA order) into a Color
    pub fn fromU32(value: u32) Color {
        return .{
            .r = @truncate(value >> 24),
            .g = @truncate(value >> 16),
            .b = @truncate(value >> 8),
            .a = @truncate(value),
        };
    }

    /// Convert to HSL color space
    pub fn toHsl(self: Color) HslColor {
        const rf: f32 = @as(f32, @floatFromInt(self.r)) / 255.0;
        const gf: f32 = @as(f32, @floatFromInt(self.g)) / 255.0;
        const bf: f32 = @as(f32, @floatFromInt(self.b)) / 255.0;

        const max = @max(rf, @max(gf, bf));
        const min = @min(rf, @min(gf, bf));
        const delta = max - min;

        var h: f32 = 0;
        var s: f32 = 0;
        const l: f32 = (max + min) / 2.0;

        if (delta > 0.0) {
            s = if (l < 0.5) delta / (max + min) else delta / (2.0 - max - min);

            if (max == rf) {
                h = (gf - bf) / delta + (if (gf < bf) @as(f32, 6.0) else @as(f32, 0.0));
            } else if (max == gf) {
                h = (bf - rf) / delta + 2.0;
            } else {
                h = (rf - gf) / delta + 4.0;
            }
            h /= 6.0;
        }

        return .{ .h = h * 360.0, .s = s, .l = l, .a = @as(f32, @floatFromInt(self.a)) / 255.0 };
    }

    /// Convert to HSV color space
    pub fn toHsv(self: Color) HsvColor {
        const rf: f32 = @as(f32, @floatFromInt(self.r)) / 255.0;
        const gf: f32 = @as(f32, @floatFromInt(self.g)) / 255.0;
        const bf: f32 = @as(f32, @floatFromInt(self.b)) / 255.0;

        const max = @max(rf, @max(gf, bf));
        const min = @min(rf, @min(gf, bf));
        const delta = max - min;

        var h: f32 = 0;
        const s: f32 = if (max > 0.0) delta / max else 0.0;
        const v: f32 = max;

        if (delta > 0.0) {
            if (max == rf) {
                h = (gf - bf) / delta + (if (gf < bf) @as(f32, 6.0) else @as(f32, 0.0));
            } else if (max == gf) {
                h = (bf - rf) / delta + 2.0;
            } else {
                h = (rf - gf) / delta + 4.0;
            }
            h /= 6.0;
        }

        return .{ .h = h * 360.0, .s = s, .v = v, .a = @as(f32, @floatFromInt(self.a)) / 255.0 };
    }

    /// Linearly interpolate between two colors
    pub fn lerp(self: Color, other: Color, t: f32) Color {
        const t_clamped = @min(@max(t, 0.0), 1.0);
        const inv = 1.0 - t_clamped;
        return .{
            .r = @intFromFloat(@as(f32, @floatFromInt(self.r)) * inv + @as(f32, @floatFromInt(other.r)) * t_clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(self.g)) * inv + @as(f32, @floatFromInt(other.g)) * t_clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(self.b)) * inv + @as(f32, @floatFromInt(other.b)) * t_clamped),
            .a = @intFromFloat(@as(f32, @floatFromInt(self.a)) * inv + @as(f32, @floatFromInt(other.a)) * t_clamped),
        };
    }

    /// Alpha-blend this color over another (Porter-Duff "over" operator)
    pub fn blendOver(self: Color, dst: Color) Color {
        const src_a: f32 = @as(f32, @floatFromInt(self.a)) / 255.0;
        const dst_a: f32 = @as(f32, @floatFromInt(dst.a)) / 255.0;
        const out_a = src_a + dst_a * (1.0 - src_a);

        if (out_a == 0.0) return Color.transparent;

        const src_r: f32 = @floatFromInt(self.r);
        const src_g: f32 = @floatFromInt(self.g);
        const src_b: f32 = @floatFromInt(self.b);
        const dst_r: f32 = @floatFromInt(dst.r);
        const dst_g: f32 = @floatFromInt(dst.g);
        const dst_b: f32 = @floatFromInt(dst.b);

        return .{
            .r = @intFromFloat((src_r * src_a + dst_r * dst_a * (1.0 - src_a)) / out_a),
            .g = @intFromFloat((src_g * src_a + dst_g * dst_a * (1.0 - src_a)) / out_a),
            .b = @intFromFloat((src_b * src_a + dst_b * dst_a * (1.0 - src_a)) / out_a),
            .a = @intFromFloat(out_a * 255.0),
        };
    }

    /// Compute luminance (perceived brightness)
    pub fn luminance(self: Color) f32 {
        return 0.2126 * @as(f32, @floatFromInt(self.r)) / 255.0 +
            0.7152 * @as(f32, @floatFromInt(self.g)) / 255.0 +
            0.0722 * @as(f32, @floatFromInt(self.b)) / 255.0;
    }

    /// Convert to grayscale
    pub fn toGrayscale(self: Color) Color {
        const gray: u8 = @intFromFloat(self.luminance() * 255.0);
        return .{ .r = gray, .g = gray, .b = gray, .a = self.a };
    }

    /// Invert the color (keep alpha)
    pub fn invert(self: Color) Color {
        return .{ .r = 255 - self.r, .g = 255 - self.g, .b = 255 - self.b, .a = self.a };
    }

    pub fn eql(self: Color, other: Color) bool {
        return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a;
    }
};

/// HSL color representation
pub const HslColor = struct {
    h: f32, // 0-360
    s: f32, // 0-1
    l: f32, // 0-1
    a: f32, // 0-1

    pub fn toRgba(self: HslColor) Color {
        if (self.s == 0.0) {
            const v: u8 = @intFromFloat(self.l * 255.0);
            return .{ .r = v, .g = v, .b = v, .a = @intFromFloat(self.a * 255.0) };
        }

        const q = if (self.l < 0.5) self.l * (1.0 + self.s) else self.l + self.s - self.l * self.s;
        const p = 2.0 * self.l - q;
        const h_norm = self.h / 360.0;

        return .{
            .r = hueToRgb(p, q, h_norm + 1.0 / 3.0),
            .g = hueToRgb(p, q, h_norm),
            .b = hueToRgb(p, q, h_norm - 1.0 / 3.0),
            .a = @intFromFloat(self.a * 255.0),
        };
    }

    fn hueToRgb(p: f32, q: f32, t_in: f32) u8 {
        var t = t_in;
        if (t < 0.0) t += 1.0;
        if (t > 1.0) t -= 1.0;

        const result = if (t < 1.0 / 6.0)
            p + (q - p) * 6.0 * t
        else if (t < 1.0 / 2.0)
            q
        else if (t < 2.0 / 3.0)
            p + (q - p) * (2.0 / 3.0 - t) * 6.0
        else
            p;

        return @intFromFloat(result * 255.0);
    }
};

/// HSV color representation
pub const HsvColor = struct {
    h: f32, // 0-360
    s: f32, // 0-1
    v: f32, // 0-1
    a: f32, // 0-1

    pub fn toRgba(self: HsvColor) Color {
        const c = self.v * self.s;
        const h_prime = self.h / 60.0;
        const h_mod = @mod(h_prime, 2.0);
        const x = c * (1.0 - @abs(h_mod - 1.0));
        const m = self.v - c;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (h_prime < 1.0) {
            r = c;
            g = x;
        } else if (h_prime < 2.0) {
            r = x;
            g = c;
        } else if (h_prime < 3.0) {
            g = c;
            b = x;
        } else if (h_prime < 4.0) {
            g = x;
            b = c;
        } else if (h_prime < 5.0) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return .{
            .r = @intFromFloat((r + m) * 255.0),
            .g = @intFromFloat((g + m) * 255.0),
            .b = @intFromFloat((b + m) * 255.0),
            .a = @intFromFloat(self.a * 255.0),
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Color.init and constants" {
    const c = Color.init(10, 20, 30, 40);
    try testing.expectEqual(@as(u8, 10), c.r);
    try testing.expectEqual(@as(u8, 20), c.g);
    try testing.expectEqual(@as(u8, 30), c.b);
    try testing.expectEqual(@as(u8, 40), c.a);

    try testing.expect(Color.black.eql(Color.init(0, 0, 0, 255)));
    try testing.expect(Color.white.eql(Color.init(255, 255, 255, 255)));
    try testing.expect(Color.transparent.eql(Color.init(0, 0, 0, 0)));
}

test "Color.fromRgb" {
    const c = Color.fromRgb(100, 150, 200);
    try testing.expectEqual(@as(u8, 255), c.a);
    try testing.expectEqual(@as(u8, 100), c.r);
}

test "Color.toU32 and fromU32 roundtrip" {
    const original = Color.init(0xAA, 0xBB, 0xCC, 0xDD);
    const as_u32 = original.toU32();
    const unpacked = Color.fromU32(as_u32);
    try testing.expect(original.eql(unpacked));
}

test "Color.toU32 known value" {
    const c = Color.init(0xFF, 0x00, 0x80, 0x40);
    try testing.expectEqual(@as(u32, 0xFF008040), c.toU32());
}

test "Color.lerp endpoints" {
    const a = Color.black;
    const b = Color.white;

    const at_zero = a.lerp(b, 0.0);
    try testing.expect(at_zero.eql(Color.black));

    const at_one = a.lerp(b, 1.0);
    try testing.expect(at_one.eql(Color.white));
}

test "Color.lerp midpoint" {
    const a = Color.init(0, 0, 0, 255);
    const b = Color.init(200, 100, 50, 255);
    const mid = a.lerp(b, 0.5);

    try testing.expectEqual(@as(u8, 100), mid.r);
    try testing.expectEqual(@as(u8, 50), mid.g);
    try testing.expectEqual(@as(u8, 25), mid.b);
}

test "Color.lerp clamps t" {
    const a = Color.black;
    const b = Color.white;
    const under = a.lerp(b, -1.0);
    const over = a.lerp(b, 2.0);
    try testing.expect(under.eql(Color.black));
    try testing.expect(over.eql(Color.white));
}

test "Color.blendOver opaque over anything" {
    const src = Color.red;
    const dst = Color.blue;
    const result = src.blendOver(dst);
    try testing.expect(result.eql(Color.red));
}

test "Color.blendOver transparent over color" {
    const src = Color.transparent;
    const dst = Color.green;
    const result = src.blendOver(dst);
    try testing.expect(result.eql(Color.green));
}

test "Color.blendOver semi-transparent" {
    const src = Color.init(255, 0, 0, 128);
    const dst = Color.init(0, 0, 255, 255);
    const result = src.blendOver(dst);
    // Semi-transparent red over opaque blue should produce purple-ish
    try testing.expect(result.r > 100);
    try testing.expect(result.b > 100);
    try testing.expectEqual(@as(u8, 255), result.a);
}

test "Color.luminance" {
    try testing.expectApproxEqAbs(@as(f32, 0.0), Color.black.luminance(), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), Color.white.luminance(), 0.001);
    // Green has highest luminance contribution
    try testing.expect(Color.green.luminance() > Color.red.luminance());
    try testing.expect(Color.green.luminance() > Color.blue.luminance());
}

test "Color.toGrayscale" {
    const gray = Color.white.toGrayscale();
    try testing.expectEqual(gray.r, gray.g);
    try testing.expectEqual(gray.g, gray.b);
    try testing.expectEqual(@as(u8, 255), gray.a);
}

test "Color.invert" {
    const inv = Color.black.invert();
    try testing.expect(inv.eql(Color.init(255, 255, 255, 255)));

    const inv2 = Color.init(100, 150, 200, 128).invert();
    try testing.expectEqual(@as(u8, 155), inv2.r);
    try testing.expectEqual(@as(u8, 105), inv2.g);
    try testing.expectEqual(@as(u8, 55), inv2.b);
    try testing.expectEqual(@as(u8, 128), inv2.a);
}

test "Color to HSL roundtrip" {
    const colors = [_]Color{
        Color.red,
        Color.green,
        Color.blue,
        Color.white,
        Color.init(128, 64, 200, 255),
    };

    for (colors) |original| {
        const hsl = original.toHsl();
        const back = hsl.toRgba();
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.r)), @as(f32, @floatFromInt(back.r)), 2.0);
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.g)), @as(f32, @floatFromInt(back.g)), 2.0);
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.b)), @as(f32, @floatFromInt(back.b)), 2.0);
    }
}

test "Color to HSV roundtrip" {
    const colors = [_]Color{
        Color.red,
        Color.green,
        Color.blue,
        Color.white,
        Color.init(200, 100, 50, 255),
    };

    for (colors) |original| {
        const hsv = original.toHsv();
        const back = hsv.toRgba();
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.r)), @as(f32, @floatFromInt(back.r)), 2.0);
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.g)), @as(f32, @floatFromInt(back.g)), 2.0);
        try testing.expectApproxEqAbs(@as(f32, @floatFromInt(original.b)), @as(f32, @floatFromInt(back.b)), 2.0);
    }
}

test "HSL known values" {
    // Pure red = H:0, S:1, L:0.5
    const red_hsl = Color.red.toHsl();
    try testing.expectApproxEqAbs(@as(f32, 0.0), red_hsl.h, 1.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), red_hsl.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.5), red_hsl.l, 0.01);

    // Black = L:0
    const black_hsl = Color.black.toHsl();
    try testing.expectApproxEqAbs(@as(f32, 0.0), black_hsl.l, 0.01);

    // White = L:1
    const white_hsl = Color.white.toHsl();
    try testing.expectApproxEqAbs(@as(f32, 1.0), white_hsl.l, 0.01);
}

test "HSV known values" {
    // Pure red = H:0, S:1, V:1
    const red_hsv = Color.red.toHsv();
    try testing.expectApproxEqAbs(@as(f32, 0.0), red_hsv.h, 1.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), red_hsv.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), red_hsv.v, 0.01);
}

test "HslColor gray (s=0)" {
    const gray = HslColor{ .h = 0, .s = 0.0, .l = 0.5, .a = 1.0 };
    const rgb = gray.toRgba();
    try testing.expectEqual(rgb.r, rgb.g);
    try testing.expectEqual(rgb.g, rgb.b);
    try testing.expectEqual(@as(u8, 127), rgb.r);
}

test "HsvColor zero saturation" {
    const gray = HsvColor{ .h = 0, .s = 0.0, .v = 0.5, .a = 1.0 };
    const rgb = gray.toRgba();
    try testing.expectEqual(rgb.r, rgb.g);
    try testing.expectEqual(rgb.g, rgb.b);
}
