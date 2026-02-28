const std = @import("std");
const testing = std.testing;
const Color = @import("../core/color.zig").Color;
const Image = @import("../core/image.zig").Image;

/// Adjust brightness and contrast
pub fn brightnessContrast(img: *Image, brightness: f32, contrast: f32) void {
    const factor = (259.0 * (contrast * 255.0 + 255.0)) / (255.0 * (259.0 - contrast * 255.0));

    for (img.pixels) |*pixel| {
        pixel.r = clamp(factor * (@as(f32, @floatFromInt(pixel.r)) - 128.0 + brightness) + 128.0);
        pixel.g = clamp(factor * (@as(f32, @floatFromInt(pixel.g)) - 128.0 + brightness) + 128.0);
        pixel.b = clamp(factor * (@as(f32, @floatFromInt(pixel.b)) - 128.0 + brightness) + 128.0);
    }
}

/// Adjust hue and saturation
pub fn hueSaturation(img: *Image, hue_shift: f32, saturation_factor: f32) void {
    for (img.pixels) |*pixel| {
        var hsl = pixel.toHsl();
        hsl.h = @mod(hsl.h + hue_shift, 360.0);
        hsl.s = @min(@max(hsl.s * saturation_factor, 0.0), 1.0);
        const result = hsl.toRgba();
        pixel.r = result.r;
        pixel.g = result.g;
        pixel.b = result.b;
    }
}

/// Apply levels adjustment
pub fn levels(img: *Image, in_black: u8, in_white: u8, out_black: u8, out_white: u8) void {
    if (in_white <= in_black) return;

    const in_range: f32 = @floatFromInt(@as(u16, in_white) - @as(u16, in_black));
    const out_range: f32 = @floatFromInt(@as(u16, out_white) - @as(u16, out_black));

    for (img.pixels) |*pixel| {
        pixel.r = mapLevel(pixel.r, in_black, in_range, out_black, out_range);
        pixel.g = mapLevel(pixel.g, in_black, in_range, out_black, out_range);
        pixel.b = mapLevel(pixel.b, in_black, in_range, out_black, out_range);
    }
}

fn mapLevel(value: u8, in_black: u8, in_range: f32, out_black: u8, out_range: f32) u8 {
    const clamped = @as(f32, @floatFromInt(@max(value, in_black) - in_black));
    const normalized = @min(clamped / in_range, 1.0);
    return clamp(normalized * out_range + @as(f32, @floatFromInt(out_black)));
}

/// Invert all colors
pub fn invertColors(img: *Image) void {
    for (img.pixels) |*pixel| {
        pixel.* = pixel.invert();
    }
}

/// Convert to grayscale
pub fn grayscale(img: *Image) void {
    for (img.pixels) |*pixel| {
        pixel.* = pixel.toGrayscale();
    }
}

/// Convert to sepia tone
pub fn sepia(img: *Image) void {
    for (img.pixels) |*pixel| {
        const r: f32 = @floatFromInt(pixel.r);
        const g: f32 = @floatFromInt(pixel.g);
        const b: f32 = @floatFromInt(pixel.b);

        pixel.r = clamp(r * 0.393 + g * 0.769 + b * 0.189);
        pixel.g = clamp(r * 0.349 + g * 0.686 + b * 0.168);
        pixel.b = clamp(r * 0.272 + g * 0.534 + b * 0.131);
    }
}

/// Apply posterize effect (reduce number of colors)
pub fn posterize(img: *Image, num_levels: u8) void {
    if (num_levels < 2) return;
    const divisor: f32 = 256.0 / @as(f32, @floatFromInt(num_levels));

    for (img.pixels) |*pixel| {
        pixel.r = @intFromFloat(@floor(@as(f32, @floatFromInt(pixel.r)) / divisor) * divisor);
        pixel.g = @intFromFloat(@floor(@as(f32, @floatFromInt(pixel.g)) / divisor) * divisor);
        pixel.b = @intFromFloat(@floor(@as(f32, @floatFromInt(pixel.b)) / divisor) * divisor);
    }
}

/// Apply threshold (convert to pure black and white)
pub fn threshold(img: *Image, thresh: u8) void {
    for (img.pixels) |*pixel| {
        const gray: u8 = @intFromFloat(pixel.luminance() * 255.0);
        const val: u8 = if (gray >= thresh) 255 else 0;
        pixel.r = val;
        pixel.g = val;
        pixel.b = val;
    }
}

fn clamp(v: f32) u8 {
    return @intFromFloat(@min(@max(v, 0.0), 255.0));
}

// ============================================================================
// Tests
// ============================================================================

test "brightnessContrast increase brightness" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(100, 100, 100, 255));
    defer img.deinit();

    brightnessContrast(&img, 50, 0);
    const pixel = img.getPixel(0, 0).?;
    try testing.expect(pixel.r > 100);
}

test "brightnessContrast increase contrast" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(200, 50, 128, 255));
    defer img.deinit();

    brightnessContrast(&img, 0, 0.5);
    const pixel = img.getPixel(0, 0).?;
    // High values get higher, low values get lower with increased contrast
    try testing.expect(pixel.r > 200 or pixel.r >= 200);
}

test "hueSaturation shifts hue" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.red);
    defer img.deinit();

    hueSaturation(&img, 120, 1.0); // shift 120 degrees = red -> green-ish
    const pixel = img.getPixel(0, 0).?;
    try testing.expect(pixel.g > pixel.r);
}

test "hueSaturation desaturate" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.red);
    defer img.deinit();

    hueSaturation(&img, 0, 0.0); // fully desaturate
    const pixel = img.getPixel(0, 0).?;
    try testing.expectEqual(pixel.r, pixel.g);
    try testing.expectEqual(pixel.g, pixel.b);
}

test "levels" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(128, 128, 128, 255));
    defer img.deinit();

    levels(&img, 0, 255, 50, 200);
    const pixel = img.getPixel(0, 0).?;
    try testing.expect(pixel.r >= 50 and pixel.r <= 200);
}

test "invertColors" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(100, 150, 200, 255));
    defer img.deinit();

    invertColors(&img);
    const pixel = img.getPixel(0, 0).?;
    try testing.expectEqual(@as(u8, 155), pixel.r);
    try testing.expectEqual(@as(u8, 105), pixel.g);
    try testing.expectEqual(@as(u8, 55), pixel.b);
}

test "grayscale" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.red);
    defer img.deinit();

    grayscale(&img);
    const pixel = img.getPixel(0, 0).?;
    try testing.expectEqual(pixel.r, pixel.g);
    try testing.expectEqual(pixel.g, pixel.b);
}

test "sepia" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(128, 128, 128, 255));
    defer img.deinit();

    sepia(&img);
    const pixel = img.getPixel(0, 0).?;
    // Sepia should have warm tones: r > g > b
    try testing.expect(pixel.r >= pixel.g);
    try testing.expect(pixel.g >= pixel.b);
}

test "posterize" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(100, 150, 200, 255));
    defer img.deinit();

    posterize(&img, 4);
    // Values should be quantized
    const pixel = img.getPixel(0, 0).?;
    try testing.expect(pixel.r % 64 == 0 or pixel.r == 0);
}

test "threshold" {
    var img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(200, 200, 200, 255));
    defer img.deinit();

    threshold(&img, 128);
    const pixel = img.getPixel(0, 0).?;
    try testing.expectEqual(@as(u8, 255), pixel.r);

    // Dark pixel below threshold
    var dark_img = try Image.initWithColor(testing.allocator, 3, 3, Color.init(50, 50, 50, 255));
    defer dark_img.deinit();
    threshold(&dark_img, 128);
    try testing.expectEqual(@as(u8, 0), dark_img.getPixel(0, 0).?.r);
}
