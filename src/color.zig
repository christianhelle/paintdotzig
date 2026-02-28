//! Color types and operations for Paint.Zig.
//! Provides RGBA, HSV, and HSL color representations with conversion
//! and blending operations optimized for image editing.

const std = @import("std");
const math = std.math;

/// 32-bit RGBA color with 8 bits per channel.
pub const Rgba = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const black = Rgba{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const white = Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const red = Rgba{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const green = Rgba{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const blue = Rgba{ .r = 0, .g = 0, .b = 255, .a = 255 };
    pub const transparent = Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 };

    /// Pack color into a u32 in RGBA byte order.
    pub fn toU32(self: Rgba) u32 {
        return (@as(u32, self.r) << 24) |
            (@as(u32, self.g) << 16) |
            (@as(u32, self.b) << 8) |
            @as(u32, self.a);
    }

    /// Pack color into a u32 in ARGB byte order (used by some renderers).
    pub fn toArgb(self: Rgba) u32 {
        return (@as(u32, self.a) << 24) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            @as(u32, self.b);
    }

    /// Unpack from u32 RGBA byte order.
    pub fn fromU32(v: u32) Rgba {
        return .{
            .r = @intCast((v >> 24) & 0xFF),
            .g = @intCast((v >> 16) & 0xFF),
            .b = @intCast((v >> 8) & 0xFF),
            .a = @intCast(v & 0xFF),
        };
    }

    /// Unpack from u32 ARGB byte order.
    pub fn fromArgb(v: u32) Rgba {
        return .{
            .a = @intCast((v >> 24) & 0xFF),
            .r = @intCast((v >> 16) & 0xFF),
            .g = @intCast((v >> 8) & 0xFF),
            .b = @intCast(v & 0xFF),
        };
    }

    /// Alpha-blend src over dst using standard Porter-Duff "over" compositing.
    pub fn blend(dst: Rgba, src: Rgba) Rgba {
        if (src.a == 0) return dst;
        if (src.a == 255) return src;

        const sa = @as(u32, src.a);
        const da = @as(u32, dst.a);
        const inv = 255 - sa;

        const out_a = sa + (da * inv) / 255;
        if (out_a == 0) return transparent;

        const r = (sa * @as(u32, src.r) + inv * da * @as(u32, dst.r) / 255) / out_a;
        const g = (sa * @as(u32, src.g) + inv * da * @as(u32, dst.g) / 255) / out_a;
        const b = (sa * @as(u32, src.b) + inv * da * @as(u32, dst.b) / 255) / out_a;

        return .{
            .r = @intCast(@min(r, 255)),
            .g = @intCast(@min(g, 255)),
            .b = @intCast(@min(b, 255)),
            .a = @intCast(@min(out_a, 255)),
        };
    }

    /// Linearly interpolate between two colors by factor t in [0, 1].
    pub fn lerp(a: Rgba, b: Rgba, t: f32) Rgba {
        const ti = @as(u8, @intFromFloat(@round(t * 255.0)));
        const inv: u32 = 255 - @as(u32, ti);
        const tf: u32 = @as(u32, ti);
        return .{
            .r = @intCast((@as(u32, a.r) * inv + @as(u32, b.r) * tf) / 255),
            .g = @intCast((@as(u32, a.g) * inv + @as(u32, b.g) * tf) / 255),
            .b = @intCast((@as(u32, a.b) * inv + @as(u32, b.b) * tf) / 255),
            .a = @intCast((@as(u32, a.a) * inv + @as(u32, b.a) * tf) / 255),
        };
    }

    /// Apply opacity multiplier (0.0–1.0) to the alpha channel.
    pub fn withAlpha(self: Rgba, opacity: f32) Rgba {
        const new_a = @as(u8, @intFromFloat(@round(@as(f32, @floatFromInt(self.a)) * opacity)));
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = new_a };
    }

    pub fn eql(self: Rgba, other: Rgba) bool {
        return self.r == other.r and self.g == other.g and
            self.b == other.b and self.a == other.a;
    }
};

/// Hue-Saturation-Value color representation (all channels in [0, 1]).
pub const Hsv = struct {
    h: f32, // hue [0, 360)
    s: f32, // saturation [0, 1]
    v: f32, // value [0, 1]

    /// Convert HSV to RGBA (fully opaque).
    pub fn toRgba(self: Hsv) Rgba {
        const h = @mod(self.h, 360.0);
        const s = math.clamp(self.s, 0.0, 1.0);
        const v = math.clamp(self.v, 0.0, 1.0);

        if (s == 0.0) {
            const c: u8 = @intFromFloat(@round(v * 255.0));
            return .{ .r = c, .g = c, .b = c, .a = 255 };
        }

        const sector = h / 60.0;
        const i: u32 = @intFromFloat(sector);
        const f = sector - @as(f32, @floatFromInt(i));
        const p: u8 = @intFromFloat(@round(v * (1.0 - s) * 255.0));
        const q: u8 = @intFromFloat(@round(v * (1.0 - s * f) * 255.0));
        const t: u8 = @intFromFloat(@round(v * (1.0 - s * (1.0 - f)) * 255.0));
        const vb: u8 = @intFromFloat(@round(v * 255.0));

        return switch (i % 6) {
            0 => .{ .r = vb, .g = t, .b = p, .a = 255 },
            1 => .{ .r = q, .g = vb, .b = p, .a = 255 },
            2 => .{ .r = p, .g = vb, .b = t, .a = 255 },
            3 => .{ .r = p, .g = q, .b = vb, .a = 255 },
            4 => .{ .r = t, .g = p, .b = vb, .a = 255 },
            else => .{ .r = vb, .g = p, .b = q, .a = 255 },
        };
    }
};

/// Convert an RGBA color to its HSV representation.
pub fn rgbaToHsv(c: Rgba) Hsv {
    const r = @as(f32, @floatFromInt(c.r)) / 255.0;
    const g = @as(f32, @floatFromInt(c.g)) / 255.0;
    const b = @as(f32, @floatFromInt(c.b)) / 255.0;

    const mx = @max(r, @max(g, b));
    const mn = @min(r, @min(g, b));
    const delta = mx - mn;

    const v = mx;
    const s = if (mx == 0.0) 0.0 else delta / mx;
    const h = if (delta == 0.0)
        0.0
    else if (mx == r)
        60.0 * @mod((g - b) / delta, 6.0)
    else if (mx == g)
        60.0 * ((b - r) / delta + 2.0)
    else
        60.0 * ((r - g) / delta + 4.0);

    return .{ .h = if (h < 0.0) h + 360.0 else h, .s = s, .v = v };
}

/// Hue-Saturation-Lightness color representation.
pub const Hsl = struct {
    h: f32, // hue [0, 360)
    s: f32, // saturation [0, 1]
    l: f32, // lightness [0, 1]

    pub fn toRgba(self: Hsl) Rgba {
        const h = @mod(self.h, 360.0);
        const s = math.clamp(self.s, 0.0, 1.0);
        const l = math.clamp(self.l, 0.0, 1.0);

        const c = (1.0 - @abs(2.0 * l - 1.0)) * s;
        const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
        const m = l - c / 2.0;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (h < 60.0) {
            r = c;
            g = x;
        } else if (h < 120.0) {
            r = x;
            g = c;
        } else if (h < 180.0) {
            g = c;
            b = x;
        } else if (h < 240.0) {
            g = x;
            b = c;
        } else if (h < 300.0) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return .{
            .r = @intFromFloat(@round((r + m) * 255.0)),
            .g = @intFromFloat(@round((g + m) * 255.0)),
            .b = @intFromFloat(@round((b + m) * 255.0)),
            .a = 255,
        };
    }
};

test "Rgba constants" {
    try std.testing.expectEqual(Rgba.black.r, 0);
    try std.testing.expectEqual(Rgba.black.a, 255);
    try std.testing.expectEqual(Rgba.white.r, 255);
    try std.testing.expectEqual(Rgba.transparent.a, 0);
}

test "Rgba.toU32 and fromU32 round-trip" {
    const c = Rgba{ .r = 0x12, .g = 0x34, .b = 0x56, .a = 0x78 };
    try std.testing.expectEqual(c, Rgba.fromU32(c.toU32()));
}

test "Rgba.toArgb and fromArgb round-trip" {
    const c = Rgba{ .r = 0xAB, .g = 0xCD, .b = 0xEF, .a = 0xFF };
    try std.testing.expectEqual(c, Rgba.fromArgb(c.toArgb()));
}

test "Rgba.blend fully opaque source" {
    const dst = Rgba.white;
    const src = Rgba.red;
    try std.testing.expectEqual(src, dst.blend(src));
}

test "Rgba.blend fully transparent source" {
    const dst = Rgba.white;
    const src = Rgba{ .r = 255, .g = 0, .b = 0, .a = 0 };
    try std.testing.expectEqual(dst, dst.blend(src));
}

test "Rgba.blend 50% alpha source" {
    const dst = Rgba.black;
    const src = Rgba{ .r = 255, .g = 255, .b = 255, .a = 128 };
    const result = dst.blend(src);
    // Result should be roughly mid-grey
    try std.testing.expect(result.r > 100 and result.r < 160);
    try std.testing.expect(result.g > 100 and result.g < 160);
}

test "Rgba.lerp midpoint" {
    const a = Rgba.black;
    const b = Rgba.white;
    const mid = a.lerp(b, 0.5);
    try std.testing.expect(mid.r >= 127 and mid.r <= 128);
}

test "Rgba.lerp endpoints" {
    const a = Rgba.red;
    const b = Rgba.blue;
    try std.testing.expectEqual(a, a.lerp(b, 0.0));
    try std.testing.expectEqual(b, a.lerp(b, 1.0));
}

test "Rgba.withAlpha" {
    const c = Rgba.red;
    const half = c.withAlpha(0.5);
    try std.testing.expect(half.a >= 127 and half.a <= 128);
    try std.testing.expectEqual(half.r, 255);
}

test "Hsv.toRgba primary colors" {
    const red_hsv = Hsv{ .h = 0.0, .s = 1.0, .v = 1.0 };
    const r = red_hsv.toRgba();
    try std.testing.expectEqual(r.r, 255);
    try std.testing.expectEqual(r.g, 0);
    try std.testing.expectEqual(r.b, 0);

    const green_hsv = Hsv{ .h = 120.0, .s = 1.0, .v = 1.0 };
    const g = green_hsv.toRgba();
    try std.testing.expectEqual(g.r, 0);
    try std.testing.expectEqual(g.g, 255);
    try std.testing.expectEqual(g.b, 0);

    const blue_hsv = Hsv{ .h = 240.0, .s = 1.0, .v = 1.0 };
    const bl = blue_hsv.toRgba();
    try std.testing.expectEqual(bl.r, 0);
    try std.testing.expectEqual(bl.g, 0);
    try std.testing.expectEqual(bl.b, 255);
}

test "Hsv.toRgba grey (zero saturation)" {
    const grey = Hsv{ .h = 0.0, .s = 0.0, .v = 0.5 };
    const c = grey.toRgba();
    try std.testing.expectEqual(c.r, c.g);
    try std.testing.expectEqual(c.g, c.b);
}

test "rgbaToHsv round-trip" {
    const original = Rgba{ .r = 200, .g = 100, .b = 50, .a = 255 };
    const hsv = rgbaToHsv(original);
    const converted = hsv.toRgba();
    // Allow ±2 rounding error per channel
    const dr = @as(i16, original.r) - @as(i16, converted.r);
    const dg = @as(i16, original.g) - @as(i16, converted.g);
    const db = @as(i16, original.b) - @as(i16, converted.b);
    try std.testing.expect(@abs(dr) <= 2);
    try std.testing.expect(@abs(dg) <= 2);
    try std.testing.expect(@abs(db) <= 2);
}

test "Hsl.toRgba primary colors" {
    const red_hsl = Hsl{ .h = 0.0, .s = 1.0, .l = 0.5 };
    const r = red_hsl.toRgba();
    try std.testing.expectEqual(r.r, 255);
    try std.testing.expectEqual(r.g, 0);
    try std.testing.expectEqual(r.b, 0);
}
