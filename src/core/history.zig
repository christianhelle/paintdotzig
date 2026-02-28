const std = @import("std");
const testing = std.testing;
const Image = @import("image.zig").Image;

/// Represents a single undoable action
pub const HistoryEntry = struct {
    name: []const u8,
    snapshot: Image,
    layer_index: usize,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HistoryEntry) void {
        self.allocator.free(self.name);
        self.snapshot.deinit();
        self.* = undefined;
    }
};

/// Undo/redo history manager
pub const History = struct {
    undo_stack: std.ArrayList(HistoryEntry),
    redo_stack: std.ArrayList(HistoryEntry),
    max_entries: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_entries: usize) History {
        return .{
            .undo_stack = .empty,
            .redo_stack = .empty,
            .max_entries = max_entries,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.undo_stack.items) |*entry| entry.deinit();
        for (self.redo_stack.items) |*entry| entry.deinit();
        self.undo_stack.deinit(self.allocator);
        self.redo_stack.deinit(self.allocator);
        self.* = undefined;
    }

    /// Push a snapshot before making changes
    pub fn pushState(self: *History, name: []const u8, image: *const Image, layer_index: usize) !void {
        // Clear redo stack on new action
        for (self.redo_stack.items) |*entry| entry.deinit();
        self.redo_stack.clearRetainingCapacity();

        // Remove oldest entry if at capacity
        if (self.max_entries > 0 and self.undo_stack.items.len >= self.max_entries) {
            var old = self.undo_stack.orderedRemove(0);
            old.deinit();
        }

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        var snapshot = try image.clone();
        errdefer snapshot.deinit();

        try self.undo_stack.append(self.allocator, .{
            .name = name_copy,
            .snapshot = snapshot,
            .layer_index = layer_index,
            .allocator = self.allocator,
        });
    }

    /// Undo: pop from undo stack, push current state to redo stack
    pub fn undo(self: *History, current_image: *const Image, current_layer: usize) !?HistoryEntry {
        if (self.undo_stack.items.len == 0) return null;

        // Save current state to redo
        const name_copy = try self.allocator.dupe(u8, "redo");
        errdefer self.allocator.free(name_copy);

        var current_snap = try current_image.clone();
        errdefer current_snap.deinit();

        try self.redo_stack.append(self.allocator, .{
            .name = name_copy,
            .snapshot = current_snap,
            .layer_index = current_layer,
            .allocator = self.allocator,
        });

        return self.undo_stack.pop();
    }

    /// Redo: pop from redo stack, push current state to undo stack
    pub fn redo(self: *History, current_image: *const Image, current_layer: usize) !?HistoryEntry {
        if (self.redo_stack.items.len == 0) return null;

        const name_copy = try self.allocator.dupe(u8, "undo");
        errdefer self.allocator.free(name_copy);

        var current_snap = try current_image.clone();
        errdefer current_snap.deinit();

        try self.undo_stack.append(self.allocator, .{
            .name = name_copy,
            .snapshot = current_snap,
            .layer_index = current_layer,
            .allocator = self.allocator,
        });

        return self.redo_stack.pop();
    }

    pub fn canUndo(self: *const History) bool {
        return self.undo_stack.items.len > 0;
    }

    pub fn canRedo(self: *const History) bool {
        return self.redo_stack.items.len > 0;
    }

    pub fn undoCount(self: *const History) usize {
        return self.undo_stack.items.len;
    }

    pub fn redoCount(self: *const History) usize {
        return self.redo_stack.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "History.init and deinit" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    try testing.expect(!history.canUndo());
    try testing.expect(!history.canRedo());
}

test "History.pushState" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();

    try history.pushState("draw", &img, 0);
    try testing.expect(history.canUndo());
    try testing.expectEqual(@as(usize, 1), history.undoCount());
}

test "History.undo" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();

    try history.pushState("draw", &img, 0);

    var entry = (try history.undo(&img, 0)).?;
    defer entry.deinit();

    try testing.expect(!history.canUndo());
    try testing.expect(history.canRedo());
}

test "History.redo" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();

    try history.pushState("draw", &img, 0);

    var entry1 = (try history.undo(&img, 0)).?;
    defer entry1.deinit();

    var entry2 = (try history.redo(&img, 0)).?;
    defer entry2.deinit();

    try testing.expect(history.canUndo());
    try testing.expect(!history.canRedo());
}

test "History.pushState clears redo" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 5, 5);
    defer img.deinit();

    try history.pushState("draw1", &img, 0);
    var entry = (try history.undo(&img, 0)).?;
    defer entry.deinit();

    try testing.expect(history.canRedo());
    try history.pushState("draw2", &img, 0);
    try testing.expect(!history.canRedo());
}

test "History max entries eviction" {
    var history = History.init(testing.allocator, 3);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 2, 2);
    defer img.deinit();

    try history.pushState("a", &img, 0);
    try history.pushState("b", &img, 0);
    try history.pushState("c", &img, 0);
    try testing.expectEqual(@as(usize, 3), history.undoCount());

    try history.pushState("d", &img, 0);
    try testing.expectEqual(@as(usize, 3), history.undoCount());
}

test "History.undo on empty returns null" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 2, 2);
    defer img.deinit();

    const result = try history.undo(&img, 0);
    try testing.expect(result == null);
}

test "History.redo on empty returns null" {
    var history = History.init(testing.allocator, 100);
    defer history.deinit();

    var img = try Image.init(testing.allocator, 2, 2);
    defer img.deinit();

    const result = try history.redo(&img, 0);
    try testing.expect(result == null);
}
