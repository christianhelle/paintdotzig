const std = @import("std");
const gui = @import("gui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try gui.run(allocator);
}

test "imports compile" {
    _ = @import("image.zig");
    _ = @import("canvas.zig");
    _ = @import("layers.zig");
    _ = @import("tools.zig");
    _ = @import("history.zig");
    _ = @import("bmp.zig");
    _ = @import("renderer.zig");
}
