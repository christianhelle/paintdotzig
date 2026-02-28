//! Undo/redo history for Paint.Zig using a command pattern.
//! Each command stores enough information to apply and revert itself.

const std = @import("std");
const color = @import("color.zig");
const canvas_mod = @import("canvas.zig");
const Rgba = color.Rgba;
const Canvas = canvas_mod.Canvas;

/// A snapshot of a single layer's pixels for undo/redo.
pub const PixelSnapshot = struct {
    layer_index: usize,
    pixels: []Rgba,
    allocator: std.mem.Allocator,

    pub fn capture(allocator: std.mem.Allocator, canvas: *const Canvas, layer_index: usize) !PixelSnapshot {
        const layer = &canvas.layers.items[layer_index];
        const pixels = try allocator.dupe(Rgba, layer.pixels);
        return .{
            .layer_index = layer_index,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PixelSnapshot) void {
        self.allocator.free(self.pixels);
    }

    /// Restore this snapshot to the canvas.
    pub fn restore(self: *const PixelSnapshot, canvas: *Canvas) void {
        if (self.layer_index >= canvas.layers.items.len) return;
        const layer = &canvas.layers.items[self.layer_index];
        if (self.pixels.len == layer.pixels.len) {
            @memcpy(layer.pixels, self.pixels);
        }
    }
};

/// A history entry holds before/after snapshots of a layer.
const HistoryEntry = struct {
    before: PixelSnapshot,
    after: PixelSnapshot,

    fn deinit(self: *HistoryEntry) void {
        self.before.deinit();
        self.after.deinit();
    }
};

/// History manager with a configurable maximum undo depth.
pub const History = struct {
    entries: std.ArrayList(HistoryEntry),
    cursor: usize, // points past the last applied entry
    max_depth: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_depth: usize) History {
        return .{
            .entries = std.ArrayList(HistoryEntry){},
            .cursor = 0,
            .max_depth = max_depth,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.entries.items) |*e| e.deinit();
        self.entries.deinit(self.allocator);
    }

    /// Record an action. `before` is the state before, `after` is after.
    /// Any redo history past the cursor is discarded.
    pub fn push(self: *History, before: PixelSnapshot, after: PixelSnapshot) !void {
        // Discard redo history beyond cursor
        while (self.entries.items.len > self.cursor) {
            var entry = self.entries.pop().?;
            entry.deinit();
        }

        // Enforce max depth by removing oldest entries
        if (self.entries.items.len >= self.max_depth) {
            var oldest = self.entries.orderedRemove(0);
            oldest.deinit();
            if (self.cursor > 0) self.cursor -= 1;
        }

        try self.entries.append(self.allocator, .{ .before = before, .after = after });
        self.cursor = self.entries.items.len;
    }

    /// Undo the last action. Returns false if nothing to undo.
    pub fn undo(self: *History, canvas: *Canvas) bool {
        if (self.cursor == 0) return false;
        self.cursor -= 1;
        self.entries.items[self.cursor].before.restore(canvas);
        return true;
    }

    /// Redo the next action. Returns false if nothing to redo.
    pub fn redo(self: *History, canvas: *Canvas) bool {
        if (self.cursor >= self.entries.items.len) return false;
        self.entries.items[self.cursor].after.restore(canvas);
        self.cursor += 1;
        return true;
    }

    pub fn canUndo(self: *const History) bool {
        return self.cursor > 0;
    }

    pub fn canRedo(self: *const History) bool {
        return self.cursor < self.entries.items.len;
    }

    pub fn clear(self: *History) void {
        for (self.entries.items) |*e| e.deinit();
        self.entries.clearRetainingCapacity();
        self.cursor = 0;
    }
};

// ─── Tests ────────────────────────────────────────────────────────────────────

test "History initial state" {
    const allocator = std.testing.allocator;
    var h = History.init(allocator, 20);
    defer h.deinit();

    try std.testing.expect(!h.canUndo());
    try std.testing.expect(!h.canRedo());
}

test "History.push and undo/redo" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 20);
    defer h.deinit();

    // Capture before state (all transparent)
    const before = try PixelSnapshot.capture(allocator, &canvas, 0);

    // Draw something
    canvas.getActiveLayer().fill(Rgba.red);

    // Capture after state
    const after = try PixelSnapshot.capture(allocator, &canvas, 0);

    try h.push(before, after);

    try std.testing.expect(h.canUndo());
    try std.testing.expect(!h.canRedo());

    // Undo: canvas should be all transparent again
    try std.testing.expect(h.undo(&canvas));
    try std.testing.expectEqual(Rgba.transparent, canvas.getActiveLayer().getPixel(0, 0).?);

    // Redo: canvas should be all red again
    try std.testing.expect(h.redo(&canvas));
    try std.testing.expectEqual(Rgba.red, canvas.getActiveLayer().getPixel(0, 0).?);
}

test "History undo at empty" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 20);
    defer h.deinit();

    try std.testing.expect(!h.undo(&canvas));
}

test "History redo at empty" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 20);
    defer h.deinit();

    try std.testing.expect(!h.redo(&canvas));
}

test "History redo clears on new push" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 20);
    defer h.deinit();

    const b1 = try PixelSnapshot.capture(allocator, &canvas, 0);
    canvas.getActiveLayer().fill(Rgba.red);
    const a1 = try PixelSnapshot.capture(allocator, &canvas, 0);
    try h.push(b1, a1);

    _ = h.undo(&canvas);
    try std.testing.expect(h.canRedo());

    // New push should discard redo
    const b2 = try PixelSnapshot.capture(allocator, &canvas, 0);
    canvas.getActiveLayer().fill(Rgba.blue);
    const a2 = try PixelSnapshot.capture(allocator, &canvas, 0);
    try h.push(b2, a2);

    try std.testing.expect(!h.canRedo());
}

test "History max depth is enforced" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 3);
    defer h.deinit();

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const b = try PixelSnapshot.capture(allocator, &canvas, 0);
        canvas.getActiveLayer().fill(Rgba{ .r = @intCast(i * 50), .g = 0, .b = 0, .a = 255 });
        const a = try PixelSnapshot.capture(allocator, &canvas, 0);
        try h.push(b, a);
    }

    try std.testing.expect(h.entries.items.len <= 3);
}

test "History.clear removes all entries" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 4, 4);
    defer canvas.deinit();
    var h = History.init(allocator, 20);
    defer h.deinit();

    const b = try PixelSnapshot.capture(allocator, &canvas, 0);
    canvas.getActiveLayer().fill(Rgba.red);
    const a = try PixelSnapshot.capture(allocator, &canvas, 0);
    try h.push(b, a);

    h.clear();
    try std.testing.expect(!h.canUndo());
    try std.testing.expect(!h.canRedo());
}
