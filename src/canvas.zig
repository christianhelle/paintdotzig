//! Canvas: a layered pixel buffer for Paint.Zig.
//! Supports multiple layers with per-layer visibility, opacity, and blend mode.

const std = @import("std");
const color = @import("color.zig");
const Rgba = color.Rgba;

pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
};

pub const Layer = struct {
    pixels: []Rgba,
    width: u32,
    height: u32,
    visible: bool,
    opacity: f32, // 0.0 – 1.0
    blend_mode: BlendMode,
    name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, name: []const u8) !Layer {
        const pixels = try allocator.alloc(Rgba, width * height);
        for (pixels) |*p| p.* = Rgba.transparent;
        return .{
            .pixels = pixels,
            .width = width,
            .height = height,
            .visible = true,
            .opacity = 1.0,
            .blend_mode = .normal,
            .name = name,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Layer) void {
        self.allocator.free(self.pixels);
    }

    pub fn getPixel(self: *const Layer, x: u32, y: u32) ?Rgba {
        if (x >= self.width or y >= self.height) return null;
        return self.pixels[y * self.width + x];
    }

    pub fn setPixel(self: *Layer, x: u32, y: u32, c: Rgba) void {
        if (x >= self.width or y >= self.height) return;
        self.pixels[y * self.width + x] = c;
    }

    /// Fill the entire layer with a solid color.
    pub fn fill(self: *Layer, c: Rgba) void {
        for (self.pixels) |*p| p.* = c;
    }

    /// Clear the layer to fully transparent.
    pub fn clear(self: *Layer) void {
        self.fill(Rgba.transparent);
    }

    /// Blit a rectangular region from src into this layer at (dst_x, dst_y).
    pub fn blit(
        self: *Layer,
        src: *const Layer,
        src_x: u32,
        src_y: u32,
        src_w: u32,
        src_h: u32,
        dst_x: u32,
        dst_y: u32,
    ) void {
        var row: u32 = 0;
        while (row < src_h) : (row += 1) {
            var col: u32 = 0;
            while (col < src_w) : (col += 1) {
                if (src_x + col >= src.width or src_y + row >= src.height) continue;
                if (dst_x + col >= self.width or dst_y + row >= self.height) continue;
                const p = src.pixels[(src_y + row) * src.width + (src_x + col)];
                self.setPixel(dst_x + col, dst_y + row, p);
            }
        }
    }
};

/// The Canvas holds all layers and composites them into a final image.
pub const Canvas = struct {
    layers: std.ArrayList(Layer),
    width: u32,
    height: u32,
    active_layer: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        var layers = std.ArrayList(Layer){};
        const bg = try Layer.init(allocator, width, height, "Background");
        try layers.append(allocator, bg);
        return .{
            .layers = layers,
            .width = width,
            .height = height,
            .active_layer = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Canvas) void {
        for (self.layers.items) |*l| l.deinit();
        self.layers.deinit(self.allocator);
    }

    /// Add a new layer on top of the stack and return its index.
    pub fn addLayer(self: *Canvas, name: []const u8) !usize {
        const layer = try Layer.init(self.allocator, self.width, self.height, name);
        try self.layers.append(self.allocator, layer);
        return self.layers.items.len - 1;
    }

    /// Remove the layer at index. Cannot remove the last layer.
    pub fn removeLayer(self: *Canvas, index: usize) bool {
        if (self.layers.items.len <= 1) return false;
        if (index >= self.layers.items.len) return false;
        self.layers.items[index].deinit();
        _ = self.layers.orderedRemove(index);
        if (self.active_layer >= self.layers.items.len) {
            self.active_layer = self.layers.items.len - 1;
        }
        return true;
    }

    /// Get the active layer for drawing.
    pub fn getActiveLayer(self: *Canvas) *Layer {
        return &self.layers.items[self.active_layer];
    }

    /// Composite all visible layers top-to-bottom into a flat Rgba buffer.
    /// Caller owns the returned slice.
    pub fn flatten(self: *const Canvas, allocator: std.mem.Allocator) ![]Rgba {
        const out = try allocator.alloc(Rgba, self.width * self.height);
        for (out) |*p| p.* = Rgba.transparent;

        for (self.layers.items) |layer| {
            if (!layer.visible) continue;
            for (layer.pixels, 0..) |src_pixel, i| {
                const src = src_pixel.withAlpha(layer.opacity);
                out[i] = blendPixels(out[i], src, layer.blend_mode);
            }
        }
        return out;
    }

    /// Resize the canvas, creating new layers at the new dimensions.
    /// Existing content is preserved by copying the overlapping region.
    pub fn resize(self: *Canvas, new_width: u32, new_height: u32) !void {
        for (self.layers.items) |*layer| {
            const new_pixels = try self.allocator.alloc(Rgba, new_width * new_height);
            for (new_pixels) |*p| p.* = Rgba.transparent;

            const copy_w = @min(layer.width, new_width);
            const copy_h = @min(layer.height, new_height);
            var row: u32 = 0;
            while (row < copy_h) : (row += 1) {
                var col: u32 = 0;
                while (col < copy_w) : (col += 1) {
                    new_pixels[row * new_width + col] =
                        layer.pixels[row * layer.width + col];
                }
            }

            self.allocator.free(layer.pixels);
            layer.pixels = new_pixels;
            layer.width = new_width;
            layer.height = new_height;
        }
        self.width = new_width;
        self.height = new_height;
    }

    fn blendPixels(dst: Rgba, src: Rgba, mode: BlendMode) Rgba {
        return switch (mode) {
            .normal => dst.blend(src),
            .multiply => blendMultiply(dst, src),
            .screen => blendScreen(dst, src),
            .overlay => blendOverlay(dst, src),
        };
    }
};

fn blendMultiply(dst: Rgba, src: Rgba) Rgba {
    const r = @as(u8, @intCast((@as(u32, dst.r) * @as(u32, src.r)) / 255));
    const g = @as(u8, @intCast((@as(u32, dst.g) * @as(u32, src.g)) / 255));
    const b = @as(u8, @intCast((@as(u32, dst.b) * @as(u32, src.b)) / 255));
    const a = @as(u8, @intCast((@as(u32, dst.a) * @as(u32, src.a)) / 255));
    return .{ .r = r, .g = g, .b = b, .a = a };
}

fn blendScreen(dst: Rgba, src: Rgba) Rgba {
    const r = @as(u8, @intCast(255 - (@as(u32, 255 - dst.r) * @as(u32, 255 - src.r)) / 255));
    const g = @as(u8, @intCast(255 - (@as(u32, 255 - dst.g) * @as(u32, 255 - src.g)) / 255));
    const b = @as(u8, @intCast(255 - (@as(u32, 255 - dst.b) * @as(u32, 255 - src.b)) / 255));
    const a = @as(u8, @intCast(255 - (@as(u32, 255 - dst.a) * @as(u32, 255 - src.a)) / 255));
    return .{ .r = r, .g = g, .b = b, .a = a };
}

fn blendOverlay(dst: Rgba, src: Rgba) Rgba {
    return .{
        .r = overlayChannel(dst.r, src.r),
        .g = overlayChannel(dst.g, src.g),
        .b = overlayChannel(dst.b, src.b),
        .a = overlayChannel(dst.a, src.a),
    };
}

fn overlayChannel(d: u8, s: u8) u8 {
    if (d < 128) {
        return @intCast((2 * @as(u32, d) * @as(u32, s)) / 255);
    } else {
        return @intCast(255 - (2 * @as(u32, 255 - d) * @as(u32, 255 - s)) / 255);
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "Layer.init creates transparent pixels" {
    const allocator = std.testing.allocator;
    var layer = try Layer.init(allocator, 4, 4, "test");
    defer layer.deinit();

    for (layer.pixels) |p| {
        try std.testing.expectEqual(Rgba.transparent, p);
    }
}

test "Layer.setPixel and getPixel" {
    const allocator = std.testing.allocator;
    var layer = try Layer.init(allocator, 8, 8, "test");
    defer layer.deinit();

    layer.setPixel(3, 5, Rgba.red);
    try std.testing.expectEqual(Rgba.red, layer.getPixel(3, 5).?);
    try std.testing.expectEqual(Rgba.transparent, layer.getPixel(0, 0).?);
}

test "Layer.setPixel out-of-bounds is ignored" {
    const allocator = std.testing.allocator;
    var layer = try Layer.init(allocator, 4, 4, "test");
    defer layer.deinit();

    layer.setPixel(100, 100, Rgba.red); // should not crash
    try std.testing.expectEqual(null, layer.getPixel(100, 100));
}

test "Layer.fill" {
    const allocator = std.testing.allocator;
    var layer = try Layer.init(allocator, 4, 4, "test");
    defer layer.deinit();

    layer.fill(Rgba.blue);
    for (layer.pixels) |p| {
        try std.testing.expectEqual(Rgba.blue, p);
    }
}

test "Canvas.init has one background layer" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 32, 32);
    defer canvas.deinit();

    try std.testing.expectEqual(@as(usize, 1), canvas.layers.items.len);
    try std.testing.expectEqual(@as(u32, 32), canvas.width);
    try std.testing.expectEqual(@as(u32, 32), canvas.height);
}

test "Canvas.addLayer increases layer count" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    _ = try canvas.addLayer("Layer 1");
    _ = try canvas.addLayer("Layer 2");
    try std.testing.expectEqual(@as(usize, 3), canvas.layers.items.len);
}

test "Canvas.removeLayer cannot remove last layer" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    try std.testing.expect(!canvas.removeLayer(0));
    try std.testing.expectEqual(@as(usize, 1), canvas.layers.items.len);
}

test "Canvas.removeLayer removes non-last layer" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 16, 16);
    defer canvas.deinit();

    _ = try canvas.addLayer("Extra");
    try std.testing.expect(canvas.removeLayer(1));
    try std.testing.expectEqual(@as(usize, 1), canvas.layers.items.len);
}

test "Canvas.flatten opaque layers" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 2, 2);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.red);
    const flat = try canvas.flatten(allocator);
    defer allocator.free(flat);

    for (flat) |p| {
        try std.testing.expectEqual(Rgba.red, p);
    }
}

test "Canvas.flatten respects layer visibility" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 2, 2);
    defer canvas.deinit();

    canvas.getActiveLayer().fill(Rgba.red);
    canvas.layers.items[0].visible = false;

    const flat = try canvas.flatten(allocator);
    defer allocator.free(flat);

    for (flat) |p| {
        try std.testing.expectEqual(Rgba.transparent, p);
    }
}

test "Canvas.resize preserves existing content" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();

    canvas.getActiveLayer().setPixel(1, 1, Rgba.green);
    try canvas.resize(8, 8);

    try std.testing.expectEqual(@as(u32, 8), canvas.width);
    try std.testing.expectEqual(Rgba.green, canvas.getActiveLayer().getPixel(1, 1).?);
}

test "blendMultiply black" {
    const result = blendMultiply(Rgba.white, Rgba.black);
    try std.testing.expectEqual(@as(u8, 0), result.r);
}

test "blendScreen white" {
    const result = blendScreen(Rgba.black, Rgba.white);
    try std.testing.expectEqual(@as(u8, 255), result.r);
}
