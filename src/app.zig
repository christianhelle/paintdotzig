//! Application state for Paint.Zig.
//! Manages the canvas, tool selection, history, and viewport.

const std = @import("std");
const canvas_mod = @import("canvas.zig");
const color = @import("color.zig");
const history_mod = @import("history.zig");
const Canvas = canvas_mod.Canvas;
const Rgba = color.Rgba;
const History = history_mod.History;
const PixelSnapshot = history_mod.PixelSnapshot;

pub const ToolKind = enum {
    pencil,
    brush,
    eraser,
    fill,
    line,
    rectangle,
    ellipse,
    selection,
    eyedropper,
    text,
};

pub const AppState = struct {
    canvas: Canvas,
    history: History,
    allocator: std.mem.Allocator,

    // Active tool settings
    active_tool: ToolKind,
    foreground_color: Rgba,
    background_color: Rgba,
    brush_size: f32,
    brush_opacity: f32,
    tolerance: u8,

    // Viewport
    zoom: f32,
    pan_x: f32,
    pan_y: f32,

    // Interaction state
    is_drawing: bool,
    last_x: f32,
    last_y: f32,

    // Pending snapshot for undo (captured at stroke start)
    pending_snapshot: ?PixelSnapshot,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !AppState {
        const canvas = try Canvas.init(allocator, width, height);
        const hist = History.init(allocator, 50);
        return .{
            .canvas = canvas,
            .history = hist,
            .allocator = allocator,
            .active_tool = .pencil,
            .foreground_color = Rgba.black,
            .background_color = Rgba.white,
            .brush_size = 3.0,
            .brush_opacity = 1.0,
            .tolerance = 15,
            .zoom = 1.0,
            .pan_x = 0.0,
            .pan_y = 0.0,
            .is_drawing = false,
            .last_x = 0.0,
            .last_y = 0.0,
            .pending_snapshot = null,
        };
    }

    pub fn deinit(self: *AppState) void {
        if (self.pending_snapshot) |*s| s.deinit();
        self.history.deinit();
        self.canvas.deinit();
    }

    /// Start a drawing stroke: capture the before-snapshot.
    pub fn beginStroke(self: *AppState, x: f32, y: f32) !void {
        self.is_drawing = true;
        self.last_x = x;
        self.last_y = y;
        if (self.pending_snapshot != null) {
            self.pending_snapshot.?.deinit();
        }
        self.pending_snapshot = try PixelSnapshot.capture(
            self.allocator,
            &self.canvas,
            self.canvas.active_layer,
        );
    }

    /// Finish a drawing stroke: capture the after-snapshot and push to history.
    pub fn endStroke(self: *AppState) !void {
        self.is_drawing = false;
        if (self.pending_snapshot) |before| {
            const after = try PixelSnapshot.capture(
                self.allocator,
                &self.canvas,
                self.canvas.active_layer,
            );
            try self.history.push(before, after);
            self.pending_snapshot = null;
        }
    }

    /// Convert screen coordinates to canvas coordinates.
    pub fn screenToCanvas(self: *const AppState, sx: f32, sy: f32) [2]f32 {
        return .{
            (sx - self.pan_x) / self.zoom,
            (sy - self.pan_y) / self.zoom,
        };
    }

    /// Perform undo.
    pub fn undo(self: *AppState) bool {
        return self.history.undo(&self.canvas);
    }

    /// Perform redo.
    pub fn redo(self: *AppState) bool {
        return self.history.redo(&self.canvas);
    }

    /// Zoom in by a factor of 1.25, capped at 32x.
    pub fn zoomIn(self: *AppState) void {
        self.zoom = @min(self.zoom * 1.25, 32.0);
    }

    /// Zoom out by a factor of 0.8, minimum 0.0625x (1/16).
    pub fn zoomOut(self: *AppState) void {
        self.zoom = @max(self.zoom * 0.8, 0.0625);
    }

    /// Reset zoom to 1:1.
    pub fn zoomReset(self: *AppState) void {
        self.zoom = 1.0;
    }

    /// Fill the active layer's background with the background color.
    pub fn fillBackground(self: *AppState) void {
        self.canvas.getActiveLayer().fill(self.background_color);
    }
};

// ─── Tests ────────────────────────────────────────────────────────────────────

test "AppState init and deinit" {
    const allocator = std.testing.allocator;
    var app = try AppState.init(allocator, 256, 256);
    defer app.deinit();

    try std.testing.expectEqual(ToolKind.pencil, app.active_tool);
    try std.testing.expectEqual(Rgba.black, app.foreground_color);
    try std.testing.expectEqual(@as(f32, 1.0), app.zoom);
}

test "AppState screenToCanvas" {
    const allocator = std.testing.allocator;
    var app = try AppState.init(allocator, 256, 256);
    defer app.deinit();

    app.zoom = 2.0;
    app.pan_x = 10.0;
    app.pan_y = 20.0;

    const pos = app.screenToCanvas(30.0, 60.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), pos[1], 0.001);
}

test "AppState zoomIn and zoomOut" {
    const allocator = std.testing.allocator;
    var app = try AppState.init(allocator, 128, 128);
    defer app.deinit();

    app.zoomIn();
    try std.testing.expect(app.zoom > 1.0);

    app.zoomOut();
    app.zoomOut();
    try std.testing.expect(app.zoom < 1.0);

    // Zoom should not exceed cap
    var i: usize = 0;
    while (i < 100) : (i += 1) app.zoomIn();
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), app.zoom, 0.001);

    // Zoom should not go below minimum
    i = 0;
    while (i < 100) : (i += 1) app.zoomOut();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0625), app.zoom, 0.001);
}

test "AppState beginStroke and endStroke creates history entry" {
    const allocator = std.testing.allocator;
    var app = try AppState.init(allocator, 32, 32);
    defer app.deinit();

    try app.beginStroke(5.0, 5.0);
    app.canvas.getActiveLayer().fill(Rgba.red);
    try app.endStroke();

    try std.testing.expect(app.history.canUndo());
}

test "AppState undo and redo" {
    const allocator = std.testing.allocator;
    var app = try AppState.init(allocator, 32, 32);
    defer app.deinit();

    try app.beginStroke(0.0, 0.0);
    app.canvas.getActiveLayer().fill(Rgba.blue);
    try app.endStroke();

    _ = app.undo();
    try std.testing.expectEqual(Rgba.transparent, app.canvas.getActiveLayer().getPixel(0, 0).?);

    _ = app.redo();
    try std.testing.expectEqual(Rgba.blue, app.canvas.getActiveLayer().getPixel(0, 0).?);
}
