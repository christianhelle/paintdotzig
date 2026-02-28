// Test entry point — imports all non-GUI modules so their inline tests
// are discovered by `zig build test`. The GUI module is excluded because
// it links raylib which requires a display server.
test "imports compile" {
    _ = @import("image.zig");
    _ = @import("canvas.zig");
    _ = @import("layers.zig");
    _ = @import("tools.zig");
    _ = @import("history.zig");
    _ = @import("bmp.zig");
    _ = @import("renderer.zig");
}
