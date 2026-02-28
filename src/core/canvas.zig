const std = @import("std");
const testing = std.testing;
const Color = @import("color.zig").Color;
const Image = @import("image.zig").Image;
const Layer = @import("layer.zig").Layer;
const LayerStack = @import("layer.zig").LayerStack;
const Selection = @import("selection.zig").Selection;
const History = @import("history.zig").History;

/// A document representing a single open image
pub const Canvas = struct {
    width: u32,
    height: u32,
    layers: LayerStack,
    selection: Selection,
    history: History,
    allocator: std.mem.Allocator,
    dirty: bool,
    file_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        var layers = LayerStack.init(allocator);
        const bg = try layers.addLayer("Background", width, height);
        bg.image.fill(Color.white);

        return .{
            .width = width,
            .height = height,
            .layers = layers,
            .selection = try Selection.init(allocator, width, height),
            .history = History.init(allocator, 0), // 0 = unlimited
            .allocator = allocator,
            .dirty = false,
            .file_path = null,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.layers.deinit();
        self.selection.deinit();
        self.history.deinit();
        if (self.file_path) |fp| self.allocator.free(fp);
        self.* = undefined;
    }

    /// Save current state before making changes
    pub fn saveState(self: *Canvas, action_name: []const u8) !void {
        const active = self.layers.activeLayer() orelse return;
        try self.history.pushState(action_name, &active.image, self.layers.active_index);
    }

    /// Undo last action
    pub fn undo(self: *Canvas) !bool {
        const active = self.layers.activeLayer() orelse return false;
        var entry = (try self.history.undo(&active.image, self.layers.active_index)) orelse return false;
        defer entry.deinit();

        if (entry.layer_index < self.layers.count()) {
            self.layers.active_index = entry.layer_index;
            const target = &self.layers.layers.items[entry.layer_index];
            @memcpy(target.image.pixels, entry.snapshot.pixels);
        }
        self.dirty = true;
        return true;
    }

    /// Redo last undone action
    pub fn redo(self: *Canvas) !bool {
        const active = self.layers.activeLayer() orelse return false;
        var entry = (try self.history.redo(&active.image, self.layers.active_index)) orelse return false;
        defer entry.deinit();

        if (entry.layer_index < self.layers.count()) {
            self.layers.active_index = entry.layer_index;
            const target = &self.layers.layers.items[entry.layer_index];
            @memcpy(target.image.pixels, entry.snapshot.pixels);
        }
        self.dirty = true;
        return true;
    }

    /// Flatten all layers and return result
    pub fn flatten(self: *Canvas) !Image {
        return self.layers.flatten(self.allocator, self.width, self.height);
    }

    /// Add a new layer above the active layer
    pub fn addLayer(self: *Canvas, name: []const u8) !void {
        _ = try self.layers.addLayer(name, self.width, self.height);
        self.dirty = true;
    }

    /// Get the active layer for drawing
    pub fn activeLayer(self: *Canvas) ?*Layer {
        return self.layers.activeLayer();
    }

    /// Resize canvas (does not resize layer contents)
    pub fn resizeCanvas(self: *Canvas, new_width: u32, new_height: u32) !void {
        var new_selection = try Selection.init(self.allocator, new_width, new_height);
        self.selection.deinit();
        self.selection = new_selection;
        _ = &new_selection;
        self.width = new_width;
        self.height = new_height;
        self.dirty = true;
    }

    pub fn setFilePath(self: *Canvas, path: []const u8) !void {
        if (self.file_path) |fp| self.allocator.free(fp);
        self.file_path = try self.allocator.dupe(u8, path);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Canvas.init creates white background" {
    var canvas = try Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    try testing.expectEqual(@as(u32, 100), canvas.width);
    try testing.expectEqual(@as(u32, 100), canvas.height);
    try testing.expectEqual(@as(usize, 1), canvas.layers.count());

    const layer = canvas.activeLayer().?;
    try testing.expect(layer.image.getPixel(0, 0).?.eql(Color.white));
}

test "Canvas.addLayer" {
    var canvas = try Canvas.init(testing.allocator, 10, 10);
    defer canvas.deinit();

    try canvas.addLayer("Layer 1");
    try testing.expectEqual(@as(usize, 2), canvas.layers.count());
}

test "Canvas.flatten" {
    var canvas = try Canvas.init(testing.allocator, 5, 5);
    defer canvas.deinit();

    var flattened = try canvas.flatten();
    defer flattened.deinit();

    try testing.expect(flattened.getPixel(0, 0).?.eql(Color.white));
}

test "Canvas.saveState and undo" {
    var canvas = try Canvas.init(testing.allocator, 5, 5);
    defer canvas.deinit();

    try canvas.saveState("before draw");
    const layer = canvas.activeLayer().?;
    layer.image.setPixel(0, 0, Color.red);

    try testing.expect(layer.image.getPixel(0, 0).?.eql(Color.red));

    const undone = try canvas.undo();
    try testing.expect(undone);

    const after_undo = canvas.activeLayer().?;
    try testing.expect(after_undo.image.getPixel(0, 0).?.eql(Color.white));
}

test "Canvas.redo" {
    var canvas = try Canvas.init(testing.allocator, 5, 5);
    defer canvas.deinit();

    try canvas.saveState("before draw");
    canvas.activeLayer().?.image.setPixel(0, 0, Color.red);

    _ = try canvas.undo();
    _ = try canvas.redo();

    // After redo, the state should be back to red
    try testing.expect(canvas.activeLayer().?.image.getPixel(0, 0).?.eql(Color.red));
}

test "Canvas.setFilePath" {
    var canvas = try Canvas.init(testing.allocator, 5, 5);
    defer canvas.deinit();

    try canvas.setFilePath("test.png");
    try testing.expectEqualStrings("test.png", canvas.file_path.?);

    try canvas.setFilePath("other.png");
    try testing.expectEqualStrings("other.png", canvas.file_path.?);
}

test "Canvas dirty flag" {
    var canvas = try Canvas.init(testing.allocator, 5, 5);
    defer canvas.deinit();

    try testing.expect(!canvas.dirty);
    try canvas.addLayer("L1");
    try testing.expect(canvas.dirty);
}
