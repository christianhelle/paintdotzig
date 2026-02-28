//! Root library module for Paint.Zig.
//! Re-exports all public modules for library consumers.

pub const color = @import("color.zig");
pub const canvas = @import("canvas.zig");
pub const history = @import("history.zig");
pub const image = @import("image.zig");
pub const app = @import("app.zig");

pub const tools = struct {
    pub const pencil = @import("tools/pencil.zig");
    pub const brush = @import("tools/brush.zig");
    pub const eraser = @import("tools/eraser.zig");
    pub const fill = @import("tools/fill.zig");
    pub const shapes = @import("tools/shapes.zig");
};

// Re-export commonly used types at the top level
pub const Rgba = color.Rgba;
pub const Hsv = color.Hsv;
pub const Canvas = canvas.Canvas;
pub const Layer = canvas.Layer;
pub const History = history.History;
pub const Image = image.Image;
pub const AppState = app.AppState;

test {
    // Run all tests in the library
    _ = @import("color.zig");
    _ = @import("canvas.zig");
    _ = @import("history.zig");
    _ = @import("image.zig");
    _ = @import("app.zig");
    _ = @import("tools/pencil.zig");
    _ = @import("tools/brush.zig");
    _ = @import("tools/eraser.zig");
    _ = @import("tools/fill.zig");
    _ = @import("tools/shapes.zig");
}
