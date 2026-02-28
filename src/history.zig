const std = @import("std");
const img = @import("image.zig");
const Image = img.Image;

/// Undo/redo history using full image snapshots.
/// Keeps up to `max_entries` states. Pushing a new state discards any
/// redo entries beyond the current position.
pub const History = struct {
    entries: std.ArrayListUnmanaged([]img.Color) = .empty,
    position: usize = 0,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,
    max_entries: usize,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, max_entries: usize) History {
        return .{
            .entries = .empty,
            .width = width,
            .height = height,
            .allocator = allocator,
            .max_entries = max_entries,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    /// Save the current image state. Discards any redo states.
    pub fn push(self: *History, image: *const Image) !void {
        // Discard redo entries
        while (self.entries.items.len > self.position) {
            if (self.entries.pop()) |removed| {
                self.allocator.free(removed);
            }
        }

        // Enforce max size
        if (self.entries.items.len >= self.max_entries) {
            const oldest = self.entries.orderedRemove(0);
            self.allocator.free(oldest);
            self.position -= 1;
        }

        const snapshot = try self.allocator.alloc(img.Color, image.pixels.len);
        @memcpy(snapshot, image.pixels);
        try self.entries.append(self.allocator, snapshot);
        self.position = self.entries.items.len;
    }

    /// Undo: restore the previous state. Returns true if undo was performed.
    pub fn undo(self: *History, image: *Image) bool {
        if (self.position <= 1) return false;
        self.position -= 1;
        @memcpy(image.pixels, self.entries.items[self.position - 1]);
        return true;
    }

    /// Redo: restore the next state. Returns true if redo was performed.
    pub fn redo(self: *History, image: *Image) bool {
        if (self.position >= self.entries.items.len) return false;
        @memcpy(image.pixels, self.entries.items[self.position]);
        self.position += 1;
        return true;
    }

    pub fn canUndo(self: *const History) bool {
        return self.position > 1;
    }

    pub fn canRedo(self: *const History) bool {
        return self.position < self.entries.items.len;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "History push and undo" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 10);
    defer history.deinit();

    // Initial state: transparent
    try history.push(&image);

    // Modify and save
    image.fill(img.Color.red);
    try history.push(&image);

    try std.testing.expect(history.canUndo());
    _ = history.undo(&image);
    // Should be back to transparent
    try std.testing.expect(image.getPixel(0, 0).?.eql(img.Color.transparent));
}

test "History redo" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 10);
    defer history.deinit();

    try history.push(&image);
    image.fill(img.Color.blue);
    try history.push(&image);

    _ = history.undo(&image);
    try std.testing.expect(history.canRedo());
    _ = history.redo(&image);
    try std.testing.expect(image.getPixel(0, 0).?.eql(img.Color.blue));
}

test "History undo at beginning returns false" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 10);
    defer history.deinit();

    try std.testing.expect(!history.undo(&image));
}

test "History redo at end returns false" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 10);
    defer history.deinit();

    try history.push(&image);
    try std.testing.expect(!history.redo(&image));
}

test "History push discards redo states" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 10);
    defer history.deinit();

    try history.push(&image);
    image.fill(img.Color.red);
    try history.push(&image);
    image.fill(img.Color.blue);
    try history.push(&image);

    // Undo twice
    _ = history.undo(&image);
    _ = history.undo(&image);

    // Push new state — should discard redo entries
    image.fill(img.Color.green);
    try history.push(&image);

    try std.testing.expect(!history.canRedo());
    try std.testing.expectEqual(@as(usize, 2), history.entries.items.len);
}

test "History enforces max_entries" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 2, 2);
    defer image.deinit();

    var history = History.init(allocator, 2, 2, 3);
    defer history.deinit();

    try history.push(&image);
    image.fill(img.Color.red);
    try history.push(&image);
    image.fill(img.Color.green);
    try history.push(&image);
    image.fill(img.Color.blue);
    try history.push(&image);

    try std.testing.expectEqual(@as(usize, 3), history.entries.items.len);
}
