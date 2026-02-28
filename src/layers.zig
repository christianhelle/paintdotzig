const std = @import("std");
const img = @import("image.zig");
const Color = img.Color;
const Image = img.Image;

/// Blend modes supported by layers.
pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
};

/// A single compositing layer with its own pixel data.
pub const Layer = struct {
    name: []const u8,
    image: Image,
    visible: bool = true,
    opacity: u8 = 255,
    blend_mode: BlendMode = .normal,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, width: u32, height: u32) !Layer {
        const owned_name = try allocator.dupe(u8, name);
        return .{
            .name = owned_name,
            .image = try Image.init(allocator, width, height),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Layer) void {
        self.allocator.free(self.name);
        self.image.deinit();
        self.* = undefined;
    }
};

/// Apply a blend mode between two colors.
fn applyBlend(dst: Color, src: Color, mode: BlendMode) Color {
    return switch (mode) {
        .normal => src,
        .multiply => Color{
            .r = @truncate((@as(u16, dst.r) * @as(u16, src.r)) / 255),
            .g = @truncate((@as(u16, dst.g) * @as(u16, src.g)) / 255),
            .b = @truncate((@as(u16, dst.b) * @as(u16, src.b)) / 255),
            .a = src.a,
        },
        .screen => Color{
            .r = @truncate(255 - (@as(u16, 255 - dst.r) * @as(u16, 255 - src.r)) / 255),
            .g = @truncate(255 - (@as(u16, 255 - dst.g) * @as(u16, 255 - src.g)) / 255),
            .b = @truncate(255 - (@as(u16, 255 - dst.b) * @as(u16, 255 - src.b)) / 255),
            .a = src.a,
        },
        .overlay => blk: {
            const ro = overlayChannel(dst.r, src.r);
            const go = overlayChannel(dst.g, src.g);
            const bo = overlayChannel(dst.b, src.b);
            break :blk Color{ .r = ro, .g = go, .b = bo, .a = src.a };
        },
    };
}

fn overlayChannel(base: u8, top: u8) u8 {
    if (base < 128) {
        return @truncate((2 * @as(u16, base) * @as(u16, top)) / 255);
    } else {
        return @truncate(255 - (2 * @as(u16, 255 - base) * @as(u16, 255 - top)) / 255);
    }
}

/// Flatten a stack of layers into a single output image.
pub fn flattenLayers(layers: []Layer, output: *Image) void {
    output.fill(Color.transparent);
    for (layers) |*layer| {
        if (!layer.visible) continue;
        const len = @min(output.pixels.len, layer.image.pixels.len);
        for (output.pixels[0..len], layer.image.pixels[0..len]) |*dst, src| {
            if (src.a == 0) continue;
            var blended_src = applyBlend(dst.*, src, layer.blend_mode);
            // Apply layer opacity
            if (layer.opacity < 255) {
                blended_src.a = @truncate((@as(u16, blended_src.a) * @as(u16, layer.opacity)) / 255);
            }
            dst.* = Color.blend(dst.*, blended_src);
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Layer.init and deinit" {
    const allocator = std.testing.allocator;
    var layer = try Layer.init(allocator, "Background", 10, 10);
    defer layer.deinit();

    try std.testing.expect(std.mem.eql(u8, layer.name, "Background"));
    try std.testing.expectEqual(@as(u32, 10), layer.image.width);
    try std.testing.expect(layer.visible);
    try std.testing.expectEqual(@as(u8, 255), layer.opacity);
}

test "flattenLayers single visible layer" {
    const allocator = std.testing.allocator;
    var l1 = try Layer.init(allocator, "L1", 2, 2);
    l1.image.fill(Color.red);

    var output = try Image.init(allocator, 2, 2);
    defer output.deinit();

    var stack = [_]Layer{l1};
    flattenLayers(&stack, &output);

    try std.testing.expect(output.getPixel(0, 0).?.eql(Color.red));
    try std.testing.expect(output.getPixel(1, 1).?.eql(Color.red));

    stack[0].deinit();
}

test "flattenLayers hidden layer is skipped" {
    const allocator = std.testing.allocator;
    var l1 = try Layer.init(allocator, "hidden", 2, 2);
    l1.image.fill(Color.green);
    l1.visible = false;

    var output = try Image.init(allocator, 2, 2);
    defer output.deinit();

    var stack = [_]Layer{l1};
    flattenLayers(&stack, &output);

    try std.testing.expect(output.getPixel(0, 0).?.eql(Color.transparent));
    stack[0].deinit();
}

test "flattenLayers two layers composite" {
    const allocator = std.testing.allocator;
    var l1 = try Layer.init(allocator, "bg", 2, 2);
    l1.image.fill(Color.blue);

    var l2 = try Layer.init(allocator, "fg", 2, 2);
    l2.image.fill(Color.red);

    var output = try Image.init(allocator, 2, 2);
    defer output.deinit();

    var stack = [_]Layer{ l1, l2 };
    flattenLayers(&stack, &output);

    // Top layer is fully opaque red, so result should be red
    try std.testing.expect(output.getPixel(0, 0).?.eql(Color.red));
    stack[0].deinit();
    stack[1].deinit();
}

test "applyBlend multiply" {
    const dst = Color{ .r = 200, .g = 100, .b = 50, .a = 255 };
    const src = Color{ .r = 128, .g = 128, .b = 128, .a = 255 };
    const result = applyBlend(dst, src, .multiply);
    // multiply: (200*128)/255 ≈ 100
    try std.testing.expect(result.r > 95 and result.r < 105);
}

test "applyBlend screen" {
    const dst = Color{ .r = 100, .g = 100, .b = 100, .a = 255 };
    const src = Color{ .r = 100, .g = 100, .b = 100, .a = 255 };
    const result = applyBlend(dst, src, .screen);
    // screen: 255 - (155*155)/255 ≈ 161
    try std.testing.expect(result.r > 155 and result.r < 170);
}

test "applyBlend normal returns src" {
    const dst = Color.blue;
    const src = Color.red;
    const result = applyBlend(dst, src, .normal);
    try std.testing.expect(result.eql(Color.red));
}
