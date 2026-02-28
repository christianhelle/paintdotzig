/// Paint.Zig GUI – thin abstraction over the raylib C API.
///
/// The window module owns the platform window and translates input events into
/// editor actions.  It uses raylib as an immediate-mode rendering backend,
/// giving us GPU-accelerated drawing with minimal overhead.
const std = @import("std");
const img = @import("image.zig");
const Color = img.Color;
const Image = img.Image;
const tools = @import("tools.zig");
const history_mod = @import("history.zig");
const layers = @import("layers.zig");
const renderer = @import("renderer.zig");
const canvas = @import("canvas.zig");
const bmp = @import("bmp.zig");

const ray = @cImport({
    @cInclude("raylib.h");
});

/// Convert our Color to raylib Color.
fn toRayColor(c: Color) ray.Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a };
}

/// Editor state that persists across frames.
pub const Editor = struct {
    canvas_image: Image,
    display_buffer: Image,
    tool_state: tools.ToolState,
    history: history_mod.History,
    texture: ray.Texture2D,
    allocator: std.mem.Allocator,
    is_drawing: bool = false,
    last_x: i32 = 0,
    last_y: i32 = 0,
    canvas_offset_x: i32 = 0,
    canvas_offset_y: i32 = 40,
    dirty: bool = true,
    zoom: f32 = 1.0,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Editor {
        var canvas_image = try Image.init(allocator, width, height);
        canvas_image.fill(Color.white);

        const display_buffer = try Image.init(allocator, width, height);

        var history = history_mod.History.init(allocator, width, height, 50);
        try history.push(&canvas_image);

        const rl_image = ray.GenImageColor(@intCast(width), @intCast(height), ray.WHITE);
        const texture = ray.LoadTextureFromImage(rl_image);
        ray.UnloadImage(rl_image);

        return .{
            .canvas_image = canvas_image,
            .display_buffer = display_buffer,
            .tool_state = .{},
            .history = history,
            .texture = texture,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Editor) void {
        ray.UnloadTexture(self.texture);
        self.history.deinit();
        self.display_buffer.deinit();
        self.canvas_image.deinit();
        self.* = undefined;
    }

    fn screenToCanvas(self: *const Editor, sx: i32, sy: i32) struct { x: i32, y: i32 } {
        const fx = @as(f32, @floatFromInt(sx - self.canvas_offset_x)) / self.zoom;
        const fy = @as(f32, @floatFromInt(sy - self.canvas_offset_y)) / self.zoom;
        return .{ .x = @intFromFloat(fx), .y = @intFromFloat(fy) };
    }

    pub fn update(self: *Editor) void {
        // Handle keyboard shortcuts
        if (ray.IsKeyDown(ray.KEY_LEFT_CONTROL) or ray.IsKeyDown(ray.KEY_RIGHT_CONTROL)) {
            if (ray.IsKeyPressed(ray.KEY_Z)) {
                if (ray.IsKeyDown(ray.KEY_LEFT_SHIFT) or ray.IsKeyDown(ray.KEY_RIGHT_SHIFT)) {
                    _ = self.history.redo(&self.canvas_image);
                } else {
                    _ = self.history.undo(&self.canvas_image);
                }
                self.dirty = true;
            }
            if (ray.IsKeyPressed(ray.KEY_S)) {
                bmp.writeBmp(&self.canvas_image, "output.bmp") catch {};
            }
        }

        // Tool switching
        if (ray.IsKeyPressed(ray.KEY_P)) self.tool_state.kind = .pencil;
        if (ray.IsKeyPressed(ray.KEY_B)) self.tool_state.kind = .brush;
        if (ray.IsKeyPressed(ray.KEY_E)) self.tool_state.kind = .eraser;
        if (ray.IsKeyPressed(ray.KEY_F)) self.tool_state.kind = .fill;
        if (ray.IsKeyPressed(ray.KEY_L)) self.tool_state.kind = .line;
        if (ray.IsKeyPressed(ray.KEY_R)) self.tool_state.kind = .rectangle;
        if (ray.IsKeyPressed(ray.KEY_C)) self.tool_state.kind = .circle;

        // Brush size
        const wheel = ray.GetMouseWheelMove();
        if (wheel > 0 and self.tool_state.brush_size < 64) {
            self.tool_state.brush_size += 1;
        } else if (wheel < 0 and self.tool_state.brush_size > 1) {
            self.tool_state.brush_size -= 1;
        }

        // Mouse input
        const mx = ray.GetMouseX();
        const my = ray.GetMouseY();
        const pt = self.screenToCanvas(mx, my);

        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            self.is_drawing = true;
            self.last_x = pt.x;
            self.last_y = pt.y;

            if (self.tool_state.kind == .fill) {
                canvas.floodFill(&self.canvas_image, pt.x, pt.y, self.tool_state.primary_color, self.allocator) catch {};
                self.dirty = true;
            } else if (self.tool_state.kind == .color_picker) {
                if (self.canvas_image.getPixel(pt.x, pt.y)) |c| {
                    self.tool_state.primary_color = c;
                }
            } else {
                self.tool_state.applyAt(&self.canvas_image, pt.x, pt.y);
                self.dirty = true;
            }
        }

        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT) and self.is_drawing) {
            if (pt.x != self.last_x or pt.y != self.last_y) {
                self.tool_state.applyStroke(&self.canvas_image, self.last_x, self.last_y, pt.x, pt.y);
                self.last_x = pt.x;
                self.last_y = pt.y;
                self.dirty = true;
            }
        }

        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT) and self.is_drawing) {
            self.is_drawing = false;
            self.history.push(&self.canvas_image) catch {};
        }
    }

    pub fn render(self: *Editor) void {
        if (self.dirty) {
            renderer.renderComposite(&self.canvas_image, &self.display_buffer);
            // Upload to GPU texture
            ray.UpdateTexture(self.texture, @ptrCast(self.display_buffer.pixels.ptr));
            self.dirty = false;
        }

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.Color{ .r = 30, .g = 30, .b = 30, .a = 255 });

        // Draw canvas
        ray.DrawTextureEx(
            self.texture,
            .{ .x = @floatFromInt(self.canvas_offset_x), .y = @floatFromInt(self.canvas_offset_y) },
            0,
            self.zoom,
            ray.WHITE,
        );

        // Draw toolbar background
        ray.DrawRectangle(0, 0, ray.GetScreenWidth(), 36, ray.Color{ .r = 50, .g = 50, .b = 50, .a = 255 });

        // Tool labels
        const tool_names = [_][*:0]const u8{
            "[P]encil", "[B]rush", "[E]raser", "[F]ill", "[L]ine", "[R]ect", "[C]ircle",
        };
        const tool_kinds = [_]tools.ToolKind{
            .pencil, .brush, .eraser, .fill, .line, .rectangle, .circle,
        };
        for (tool_names, tool_kinds, 0..) |name, kind, i| {
            const x_pos: c_int = @intCast(10 + i * 80);
            const color = if (self.tool_state.kind == kind)
                ray.Color{ .r = 255, .g = 200, .b = 0, .a = 255 }
            else
                ray.Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
            ray.DrawText(name, x_pos, 10, 16, color);
        }

        // Current color swatch
        const sw_x = ray.GetScreenWidth() - 60;
        ray.DrawRectangle(sw_x, 4, 28, 28, toRayColor(self.tool_state.primary_color));
        ray.DrawRectangleLines(sw_x, 4, 28, 28, ray.WHITE);

        // Brush size indicator
        var buf: [32]u8 = undefined;
        const size_text = std.fmt.bufPrint(&buf, "Size: {d}", .{self.tool_state.brush_size}) catch "?";
        // null-terminate for raylib
        if (size_text.len < buf.len) {
            buf[size_text.len] = 0;
            ray.DrawText(@ptrCast(&buf), sw_x - 100, 10, 16, ray.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
        }

        // Status bar
        const sb_y = ray.GetScreenHeight() - 24;
        ray.DrawRectangle(0, sb_y, ray.GetScreenWidth(), 24, ray.Color{ .r = 50, .g = 50, .b = 50, .a = 255 });

        var status_buf: [128]u8 = undefined;
        const status = std.fmt.bufPrint(&status_buf, "{d}x{d}  Zoom: {d:.0}%", .{
            self.canvas_image.width,
            self.canvas_image.height,
            self.zoom * 100,
        }) catch "?";
        if (status.len < status_buf.len) {
            status_buf[status.len] = 0;
            ray.DrawText(@ptrCast(&status_buf), 10, sb_y + 4, 14, ray.Color{ .r = 180, .g = 180, .b = 180, .a = 255 });
        }
    }
};

pub fn run(allocator: std.mem.Allocator) !void {
    const initial_w: u32 = 800;
    const initial_h: u32 = 600;

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.InitWindow(1024, 768, "Paint.Zig");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var editor = try Editor.init(allocator, initial_w, initial_h);
    defer editor.deinit();

    while (!ray.WindowShouldClose()) {
        editor.update();
        editor.render();
    }
}
