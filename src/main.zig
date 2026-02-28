const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Paint.Zig v0.1.0 - A fast, cross-platform image editor\n", .{});
}

test "imports" {
    _ = @import("core/color.zig");
    _ = @import("core/image.zig");
    _ = @import("core/layer.zig");
    _ = @import("core/history.zig");
    _ = @import("core/selection.zig");
    _ = @import("core/canvas.zig");
    _ = @import("effects/effects.zig");
    _ = @import("adjustments/adjustments.zig");
    _ = @import("tools/tools.zig");
    _ = @import("formats/bmp.zig");
}
