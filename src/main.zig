const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Paint.Zig v0.1.0 - A fast, cross-platform image editor\n", .{});
}

test "imports" {
    _ = @import("core/color.zig");
    _ = @import("core/image.zig");
}
