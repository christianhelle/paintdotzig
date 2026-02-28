const std = @import("std");
const testing = std.testing;
const Color = @import("color.zig").Color;
const Image = @import("image.zig").Image;

/// Blend mode for compositing layers
pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
    darken,
    lighten,
    color_dodge,
    color_burn,
    hard_light,
    soft_light,
    difference,
    exclusion,
    additive,

    /// Apply blend mode to two color channels (0-1 range)
    fn apply(self: BlendMode, a: f32, b: f32) f32 {
        return switch (self) {
            .normal => a,
            .multiply => a * b,
            .screen => 1.0 - (1.0 - a) * (1.0 - b),
            .overlay => if (b < 0.5) 2.0 * a * b else 1.0 - 2.0 * (1.0 - a) * (1.0 - b),
            .darken => @min(a, b),
            .lighten => @max(a, b),
            .color_dodge => if (a >= 1.0) 1.0 else @min(1.0, b / (1.0 - a)),
            .color_burn => if (a <= 0.0) 0.0 else 1.0 - @min(1.0, (1.0 - b) / a),
            .hard_light => if (a < 0.5) 2.0 * a * b else 1.0 - 2.0 * (1.0 - a) * (1.0 - b),
            .soft_light => blk: {
                const d = if (b <= 0.25) ((16.0 * b - 12.0) * b + 4.0) * b else @sqrt(b);
                break :blk if (a <= 0.5) b - (1.0 - 2.0 * a) * b * (1.0 - b) else b + (2.0 * a - 1.0) * (d - b);
            },
            .difference => @abs(a - b),
            .exclusion => a + b - 2.0 * a * b,
            .additive => @min(1.0, a + b),
        };
    }

    /// Blend two colors using this blend mode
    pub fn blend(self: BlendMode, src: Color, dst: Color, opacity: f32) Color {
        const src_a = @as(f32, @floatFromInt(src.a)) / 255.0 * opacity;
        if (src_a == 0.0) return dst;

        const dst_a = @as(f32, @floatFromInt(dst.a)) / 255.0;

        const sr: f32 = @as(f32, @floatFromInt(src.r)) / 255.0;
        const sg: f32 = @as(f32, @floatFromInt(src.g)) / 255.0;
        const sb: f32 = @as(f32, @floatFromInt(src.b)) / 255.0;
        const dr: f32 = @as(f32, @floatFromInt(dst.r)) / 255.0;
        const dg: f32 = @as(f32, @floatFromInt(dst.g)) / 255.0;
        const db: f32 = @as(f32, @floatFromInt(dst.b)) / 255.0;

        const br = self.apply(sr, dr);
        const bg = self.apply(sg, dg);
        const bb = self.apply(sb, db);

        const out_a = src_a + dst_a * (1.0 - src_a);
        if (out_a == 0.0) return Color.transparent;

        const out_r = (br * src_a + dr * dst_a * (1.0 - src_a)) / out_a;
        const out_g = (bg * src_a + dg * dst_a * (1.0 - src_a)) / out_a;
        const out_b = (bb * src_a + db * dst_a * (1.0 - src_a)) / out_a;

        return .{
            .r = @intFromFloat(@min(@max(out_r, 0.0), 1.0) * 255.0),
            .g = @intFromFloat(@min(@max(out_g, 0.0), 1.0) * 255.0),
            .b = @intFromFloat(@min(@max(out_b, 0.0), 1.0) * 255.0),
            .a = @intFromFloat(@min(out_a, 1.0) * 255.0),
        };
    }
};

/// A single layer in the image
pub const Layer = struct {
    name: []const u8,
    image: Image,
    visible: bool,
    opacity: f32, // 0.0 - 1.0
    blend_mode: BlendMode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, width: u32, height: u32) !Layer {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .image = try Image.init(allocator, width, height),
            .visible = true,
            .opacity = 1.0,
            .blend_mode = .normal,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Layer) void {
        self.allocator.free(self.name);
        self.image.deinit();
        self.* = undefined;
    }

    pub fn clone(self: *const Layer) !Layer {
        const name_copy = try self.allocator.dupe(u8, self.name);
        return .{
            .name = name_copy,
            .image = try self.image.clone(),
            .visible = self.visible,
            .opacity = self.opacity,
            .blend_mode = self.blend_mode,
            .allocator = self.allocator,
        };
    }
};

/// A stack of layers composited together
pub const LayerStack = struct {
    layers: std.ArrayList(Layer),
    active_index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LayerStack {
        return .{
            .layers = .empty,
            .active_index = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LayerStack) void {
        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn addLayer(self: *LayerStack, name: []const u8, width: u32, height: u32) !*Layer {
        var layer = try Layer.init(self.allocator, name, width, height);
        errdefer layer.deinit();
        try self.layers.append(self.allocator, layer);
        return &self.layers.items[self.layers.items.len - 1];
    }

    pub fn removeLayer(self: *LayerStack, layer_index: usize) !void {
        if (layer_index >= self.layers.items.len) return error.IndexOutOfBounds;
        if (self.layers.items.len <= 1) return error.CannotRemoveLastLayer;

        var layer = self.layers.orderedRemove(layer_index);
        layer.deinit();

        if (self.active_index >= self.layers.items.len) {
            self.active_index = self.layers.items.len - 1;
        }
    }

    pub fn moveLayer(self: *LayerStack, from: usize, to: usize) !void {
        if (from >= self.layers.items.len or to >= self.layers.items.len) return error.IndexOutOfBounds;
        if (from == to) return;

        const layer = self.layers.orderedRemove(from);
        try self.layers.insert(self.allocator, to, layer);

        if (self.active_index == from) {
            self.active_index = to;
        }
    }

    pub fn duplicateLayer(self: *LayerStack, layer_index: usize) !void {
        if (layer_index >= self.layers.items.len) return error.IndexOutOfBounds;

        var cloned = try self.layers.items[layer_index].clone();
        errdefer cloned.deinit();
        try self.layers.insert(self.allocator, layer_index + 1, cloned);
    }

    pub fn activeLayer(self: *LayerStack) ?*Layer {
        if (self.active_index >= self.layers.items.len) return null;
        return &self.layers.items[self.active_index];
    }

    /// Flatten all visible layers into a single image
    pub fn flatten(self: *LayerStack, allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        var result = try Image.init(allocator, width, height);

        for (self.layers.items) |*layer| {
            if (!layer.visible or layer.opacity == 0.0) continue;

            var y: u32 = 0;
            while (y < @min(height, layer.image.height)) : (y += 1) {
                var x: u32 = 0;
                while (x < @min(width, layer.image.width)) : (x += 1) {
                    const src = layer.image.getPixel(x, y) orelse continue;
                    const dst = result.getPixel(x, y) orelse continue;
                    const blended = layer.blend_mode.blend(src, dst, layer.opacity);
                    result.setPixel(x, y, blended);
                }
            }
        }

        return result;
    }

    pub fn count(self: *const LayerStack) usize {
        return self.layers.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BlendMode.normal" {
    const result = BlendMode.normal.blend(Color.red, Color.blue, 1.0);
    try testing.expect(result.eql(Color.red));
}

test "BlendMode.normal with zero opacity" {
    const result = BlendMode.normal.blend(Color.red, Color.blue, 0.0);
    try testing.expect(result.eql(Color.blue));
}

test "BlendMode.normal with half opacity" {
    const result = BlendMode.normal.blend(Color.red, Color.blue, 0.5);
    try testing.expect(result.r > 100);
    try testing.expect(result.b > 100);
}

test "BlendMode.multiply black" {
    const result = BlendMode.multiply.blend(Color.black, Color.white, 1.0);
    try testing.expectEqual(@as(u8, 0), result.r);
    try testing.expectEqual(@as(u8, 0), result.g);
    try testing.expectEqual(@as(u8, 0), result.b);
}

test "BlendMode.screen" {
    const result = BlendMode.screen.blend(Color.white, Color.black, 1.0);
    try testing.expectEqual(@as(u8, 255), result.r);
    try testing.expectEqual(@as(u8, 255), result.g);
    try testing.expectEqual(@as(u8, 255), result.b);
}

test "BlendMode.additive" {
    const a = Color.init(100, 100, 100, 255);
    const b = Color.init(200, 200, 200, 255);
    const result = BlendMode.additive.blend(a, b, 1.0);
    try testing.expectEqual(@as(u8, 255), result.r); // clamped
}

test "BlendMode.difference" {
    const result = BlendMode.difference.blend(Color.white, Color.white, 1.0);
    try testing.expectEqual(@as(u8, 0), result.r);
}

test "Layer.init and deinit" {
    var layer = try Layer.init(testing.allocator, "Background", 10, 10);
    defer layer.deinit();

    try testing.expectEqualStrings("Background", layer.name);
    try testing.expect(layer.visible);
    try testing.expectApproxEqAbs(@as(f32, 1.0), layer.opacity, 0.001);
}

test "Layer.clone" {
    var original = try Layer.init(testing.allocator, "Test", 5, 5);
    defer original.deinit();

    original.image.setPixel(0, 0, Color.red);

    var cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqualStrings("Test", cloned.name);
    try testing.expect(cloned.image.getPixel(0, 0).?.eql(Color.red));
}

test "LayerStack basic operations" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    _ = try stack.addLayer("Background", 10, 10);
    _ = try stack.addLayer("Layer 1", 10, 10);
    try testing.expectEqual(@as(usize, 2), stack.count());

    const active = stack.activeLayer().?;
    try testing.expectEqualStrings("Background", active.name);
}

test "LayerStack.removeLayer" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    _ = try stack.addLayer("BG", 10, 10);
    _ = try stack.addLayer("L1", 10, 10);
    try stack.removeLayer(1);
    try testing.expectEqual(@as(usize, 1), stack.count());
}

test "LayerStack.removeLayer last layer fails" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    _ = try stack.addLayer("BG", 10, 10);
    try testing.expectError(error.CannotRemoveLastLayer, stack.removeLayer(0));
}

test "LayerStack.moveLayer" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    _ = try stack.addLayer("A", 5, 5);
    _ = try stack.addLayer("B", 5, 5);
    _ = try stack.addLayer("C", 5, 5);

    try stack.moveLayer(0, 2);
    try testing.expectEqualStrings("B", stack.layers.items[0].name);
    try testing.expectEqualStrings("C", stack.layers.items[1].name);
    try testing.expectEqualStrings("A", stack.layers.items[2].name);
}

test "LayerStack.duplicateLayer" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    _ = try stack.addLayer("BG", 5, 5);
    try stack.duplicateLayer(0);
    try testing.expectEqual(@as(usize, 2), stack.count());
}

test "LayerStack.flatten single layer" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    const layer = try stack.addLayer("BG", 5, 5);
    layer.image.fill(Color.red);

    var result = try stack.flatten(testing.allocator, 5, 5);
    defer result.deinit();

    try testing.expect(result.getPixel(0, 0).?.eql(Color.red));
}

test "LayerStack.flatten hides invisible layers" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    const bg = try stack.addLayer("BG", 5, 5);
    bg.image.fill(Color.white);

    const top = try stack.addLayer("Top", 5, 5);
    top.image.fill(Color.red);
    top.visible = false;

    var result = try stack.flatten(testing.allocator, 5, 5);
    defer result.deinit();

    try testing.expect(result.getPixel(0, 0).?.eql(Color.white));
}

test "LayerStack.flatten multiple layers" {
    var stack = LayerStack.init(testing.allocator);
    defer stack.deinit();

    const bg = try stack.addLayer("BG", 5, 5);
    bg.image.fill(Color.blue);

    const top = try stack.addLayer("Top", 5, 5);
    top.image.fill(Color.red);

    var result = try stack.flatten(testing.allocator, 5, 5);
    defer result.deinit();

    // Red on top of blue, both opaque = red
    try testing.expect(result.getPixel(0, 0).?.eql(Color.red));
}
