const std = @import("std");
const testing = std.testing;
const Color = @import("../core/color.zig").Color;
const Image = @import("../core/image.zig").Image;

/// Apply Gaussian blur to an image
pub fn gaussianBlur(img: *Image, radius: u32) void {
    if (radius == 0) return;
    horizontalBlur(img, radius);
    verticalBlur(img, radius);
    // Two-pass approximation for Gaussian
    horizontalBlur(img, radius);
    verticalBlur(img, radius);
}

/// Apply box blur (single pass horizontal)
fn horizontalBlur(img: *Image, radius: u32) void {
    const w = img.width;
    const h = img.height;
    const diameter = radius * 2 + 1;
    const inv: f32 = 1.0 / @as(f32, @floatFromInt(diameter));

    var y: u32 = 0;
    while (y < h) : (y += 1) {
        var sum_r: f32 = 0;
        var sum_g: f32 = 0;
        var sum_b: f32 = 0;
        var sum_a: f32 = 0;

        // Initialize with first pixel * radius (edge handling)
        const first = img.getPixel(0, y) orelse Color.transparent;
        sum_r = @as(f32, @floatFromInt(first.r)) * @as(f32, @floatFromInt(radius + 1));
        sum_g = @as(f32, @floatFromInt(first.g)) * @as(f32, @floatFromInt(radius + 1));
        sum_b = @as(f32, @floatFromInt(first.b)) * @as(f32, @floatFromInt(radius + 1));
        sum_a = @as(f32, @floatFromInt(first.a)) * @as(f32, @floatFromInt(radius + 1));

        var i: u32 = 1;
        while (i <= radius) : (i += 1) {
            const p = img.getPixel(@min(i, w - 1), y) orelse Color.transparent;
            sum_r += @floatFromInt(p.r);
            sum_g += @floatFromInt(p.g);
            sum_b += @floatFromInt(p.b);
            sum_a += @floatFromInt(p.a);
        }

        var x: u32 = 0;
        while (x < w) : (x += 1) {
            img.setPixel(x, y, .{
                .r = @intFromFloat(@min(@max(sum_r * inv, 0), 255)),
                .g = @intFromFloat(@min(@max(sum_g * inv, 0), 255)),
                .b = @intFromFloat(@min(@max(sum_b * inv, 0), 255)),
                .a = @intFromFloat(@min(@max(sum_a * inv, 0), 255)),
            });

            const add_x = @min(x + radius + 1, w - 1);
            const sub_x = if (x >= radius) x - radius else 0;
            const add_p = img.getPixel(add_x, y) orelse Color.transparent;
            const sub_p = img.getPixel(sub_x, y) orelse Color.transparent;

            sum_r += @as(f32, @floatFromInt(add_p.r)) - @as(f32, @floatFromInt(sub_p.r));
            sum_g += @as(f32, @floatFromInt(add_p.g)) - @as(f32, @floatFromInt(sub_p.g));
            sum_b += @as(f32, @floatFromInt(add_p.b)) - @as(f32, @floatFromInt(sub_p.b));
            sum_a += @as(f32, @floatFromInt(add_p.a)) - @as(f32, @floatFromInt(sub_p.a));
        }
    }
}

/// Apply box blur (single pass vertical)
fn verticalBlur(img: *Image, radius: u32) void {
    const w = img.width;
    const h = img.height;
    const diameter = radius * 2 + 1;
    const inv: f32 = 1.0 / @as(f32, @floatFromInt(diameter));

    var x: u32 = 0;
    while (x < w) : (x += 1) {
        var sum_r: f32 = 0;
        var sum_g: f32 = 0;
        var sum_b: f32 = 0;
        var sum_a: f32 = 0;

        const first = img.getPixel(x, 0) orelse Color.transparent;
        sum_r = @as(f32, @floatFromInt(first.r)) * @as(f32, @floatFromInt(radius + 1));
        sum_g = @as(f32, @floatFromInt(first.g)) * @as(f32, @floatFromInt(radius + 1));
        sum_b = @as(f32, @floatFromInt(first.b)) * @as(f32, @floatFromInt(radius + 1));
        sum_a = @as(f32, @floatFromInt(first.a)) * @as(f32, @floatFromInt(radius + 1));

        var i: u32 = 1;
        while (i <= radius) : (i += 1) {
            const p = img.getPixel(x, @min(i, h - 1)) orelse Color.transparent;
            sum_r += @floatFromInt(p.r);
            sum_g += @floatFromInt(p.g);
            sum_b += @floatFromInt(p.b);
            sum_a += @floatFromInt(p.a);
        }

        var y: u32 = 0;
        while (y < h) : (y += 1) {
            img.setPixel(x, y, .{
                .r = @intFromFloat(@min(@max(sum_r * inv, 0), 255)),
                .g = @intFromFloat(@min(@max(sum_g * inv, 0), 255)),
                .b = @intFromFloat(@min(@max(sum_b * inv, 0), 255)),
                .a = @intFromFloat(@min(@max(sum_a * inv, 0), 255)),
            });

            const add_y = @min(y + radius + 1, h - 1);
            const sub_y = if (y >= radius) y - radius else 0;
            const add_p = img.getPixel(x, add_y) orelse Color.transparent;
            const sub_p = img.getPixel(x, sub_y) orelse Color.transparent;

            sum_r += @as(f32, @floatFromInt(add_p.r)) - @as(f32, @floatFromInt(sub_p.r));
            sum_g += @as(f32, @floatFromInt(add_p.g)) - @as(f32, @floatFromInt(sub_p.g));
            sum_b += @as(f32, @floatFromInt(add_p.b)) - @as(f32, @floatFromInt(sub_p.b));
            sum_a += @as(f32, @floatFromInt(add_p.a)) - @as(f32, @floatFromInt(sub_p.a));
        }
    }
}

/// Apply sharpening (unsharp mask)
pub fn sharpen(img: *Image, amount: f32) !void {
    var blurred = try img.clone();
    defer blurred.deinit();
    gaussianBlur(&blurred, 1);

    var y: u32 = 0;
    while (y < img.height) : (y += 1) {
        var x: u32 = 0;
        while (x < img.width) : (x += 1) {
            const orig = img.getPixel(x, y) orelse continue;
            const blur = blurred.getPixel(x, y) orelse continue;

            const r = clampF32(@as(f32, @floatFromInt(orig.r)) + (@as(f32, @floatFromInt(orig.r)) - @as(f32, @floatFromInt(blur.r))) * amount);
            const g = clampF32(@as(f32, @floatFromInt(orig.g)) + (@as(f32, @floatFromInt(orig.g)) - @as(f32, @floatFromInt(blur.g))) * amount);
            const b = clampF32(@as(f32, @floatFromInt(orig.b)) + (@as(f32, @floatFromInt(orig.b)) - @as(f32, @floatFromInt(blur.b))) * amount);

            img.setPixel(x, y, .{ .r = r, .g = g, .b = b, .a = orig.a });
        }
    }
}

/// Add random noise to an image
pub fn addNoise(img: *Image, intensity: u8, seed: u64) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (img.pixels) |*pixel| {
        const noise_r: i16 = @as(i16, @intCast(random.intRangeAtMost(u8, 0, intensity))) - @as(i16, intensity / 2);
        const noise_g: i16 = @as(i16, @intCast(random.intRangeAtMost(u8, 0, intensity))) - @as(i16, intensity / 2);
        const noise_b: i16 = @as(i16, @intCast(random.intRangeAtMost(u8, 0, intensity))) - @as(i16, intensity / 2);

        pixel.r = @intCast(std.math.clamp(@as(i16, pixel.r) + noise_r, 0, 255));
        pixel.g = @intCast(std.math.clamp(@as(i16, pixel.g) + noise_g, 0, 255));
        pixel.b = @intCast(std.math.clamp(@as(i16, pixel.b) + noise_b, 0, 255));
    }
}

/// Apply emboss effect
pub fn emboss(img: *Image) !void {
    var src = try img.clone();
    defer src.deinit();

    // Emboss kernel: [[-2,-1,0],[-1,1,1],[0,1,2]]
    var y: u32 = 1;
    while (y < img.height - 1) : (y += 1) {
        var x: u32 = 1;
        while (x < img.width - 1) : (x += 1) {
            const tl = src.getPixel(x - 1, y - 1) orelse continue;
            const ml = src.getPixel(x - 1, y) orelse continue;
            const bl = src.getPixel(x, y + 1) orelse continue;
            const mr = src.getPixel(x + 1, y) orelse continue;
            const br = src.getPixel(x + 1, y + 1) orelse continue;
            const center = src.getPixel(x, y) orelse continue;
            const tr = src.getPixel(x + 1, y - 1) orelse continue;

            _ = tr;

            const r = clampF32(128.0 + (-2.0 * @as(f32, @floatFromInt(tl.r)) - @as(f32, @floatFromInt(ml.r)) + @as(f32, @floatFromInt(center.r)) + @as(f32, @floatFromInt(mr.r)) + @as(f32, @floatFromInt(bl.r)) + 2.0 * @as(f32, @floatFromInt(br.r))) / 1.0);
            const g = clampF32(128.0 + (-2.0 * @as(f32, @floatFromInt(tl.g)) - @as(f32, @floatFromInt(ml.g)) + @as(f32, @floatFromInt(center.g)) + @as(f32, @floatFromInt(mr.g)) + @as(f32, @floatFromInt(bl.g)) + 2.0 * @as(f32, @floatFromInt(br.g))) / 1.0);
            const b = clampF32(128.0 + (-2.0 * @as(f32, @floatFromInt(tl.b)) - @as(f32, @floatFromInt(ml.b)) + @as(f32, @floatFromInt(center.b)) + @as(f32, @floatFromInt(mr.b)) + @as(f32, @floatFromInt(bl.b)) + 2.0 * @as(f32, @floatFromInt(br.b))) / 1.0);

            img.setPixel(x, y, .{ .r = r, .g = g, .b = b, .a = center.a });
        }
    }
}

fn clampF32(v: f32) u8 {
    return @intFromFloat(@min(@max(v, 0.0), 255.0));
}

// ============================================================================
// Tests
// ============================================================================

test "gaussianBlur does not crash" {
    var img = try Image.initWithColor(testing.allocator, 10, 10, Color.red);
    defer img.deinit();

    gaussianBlur(&img, 2);
    // Corners should still be reddish
    const pixel = img.getPixel(5, 5).?;
    try testing.expect(pixel.a > 0);
}

test "gaussianBlur with radius 0 is no-op" {
    var img = try Image.initWithColor(testing.allocator, 5, 5, Color.red);
    defer img.deinit();

    gaussianBlur(&img, 0);
    try testing.expect(img.getPixel(2, 2).?.eql(Color.red));
}

test "sharpen does not crash" {
    var img = try Image.initWithColor(testing.allocator, 10, 10, Color.init(128, 128, 128, 255));
    defer img.deinit();

    try sharpen(&img, 1.0);
    const pixel = img.getPixel(5, 5).?;
    try testing.expect(pixel.a > 0);
}

test "addNoise modifies pixels" {
    var img = try Image.initWithColor(testing.allocator, 10, 10, Color.init(128, 128, 128, 255));
    defer img.deinit();

    addNoise(&img, 50, 42);

    // At least some pixels should have changed
    var changed = false;
    for (img.pixels) |p| {
        if (p.r != 128 or p.g != 128 or p.b != 128) {
            changed = true;
            break;
        }
    }
    try testing.expect(changed);
}

test "emboss does not crash" {
    var img = try Image.initWithColor(testing.allocator, 10, 10, Color.init(100, 150, 200, 255));
    defer img.deinit();

    try emboss(&img);
    const pixel = img.getPixel(5, 5).?;
    try testing.expect(pixel.a > 0);
}

test "clampF32" {
    try testing.expectEqual(@as(u8, 0), clampF32(-10.0));
    try testing.expectEqual(@as(u8, 255), clampF32(300.0));
    try testing.expectEqual(@as(u8, 128), clampF32(128.0));
}
