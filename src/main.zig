const std = @import("std");
const rl = @import("raylib");

const WINDOW_TITLE = "Paint.Zig v0.1.0";
const DEFAULT_WIDTH = 1280;
const DEFAULT_HEIGHT = 800;
const MIN_WIDTH = 800;
const MIN_HEIGHT = 600;

// UI layout constants
const MENUBAR_HEIGHT = 25;
const TOOLBAR_HEIGHT = 40;
const TOOLBAR_Y = MENUBAR_HEIGHT;
const CANVAS_Y = MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
const STATUSBAR_HEIGHT = 24;
const SIDEBAR_WIDTH = 200;
const COLOR_PANEL_HEIGHT = 160;

// Paint.NET-style dark theme colors
const UI_BG = rl.Color.init(45, 45, 48, 255);
const UI_PANEL = rl.Color.init(37, 37, 38, 255);
const UI_BORDER = rl.Color.init(63, 63, 70, 255);
const UI_HOVER = rl.Color.init(62, 62, 64, 255);
const UI_ACTIVE = rl.Color.init(0, 122, 204, 255);
const UI_TEXT = rl.Color.init(220, 220, 220, 255);
const UI_TEXT_DIM = rl.Color.init(150, 150, 150, 255);
const CANVAS_BG = rl.Color.init(32, 32, 32, 255);
const CHECKER_LIGHT = rl.Color.init(204, 204, 204, 255);
const CHECKER_DARK = rl.Color.init(170, 170, 170, 255);

const ToolKind = enum {
    rectangle_select,
    move,
    lasso,
    wand,
    bucket,
    gradient,
    brush,
    eraser,
    pencil,
    picker,
    clone,
    text,
    line,
    rectangle,
    ellipse,
    zoom,
};

const tool_names = [_][:0]const u8{
    "Rect Sel",
    "Move",
    "Lasso",
    "Wand",
    "Bucket",
    "Gradient",
    "Brush",
    "Eraser",
    "Pencil",
    "Picker",
    "Clone",
    "Text",
    "Line",
    "Rect",
    "Ellipse",
    "Zoom",
};

const AppState = struct {
    canvas_width: i32 = 800,
    canvas_height: i32 = 600,
    canvas_texture: ?rl.Texture2D = null,
    canvas_pixels: ?[]u8 = null,
    canvas_dirty: bool = true,
    current_tool: ToolKind = .brush,
    primary_color: [3]u8 = .{ 0, 0, 0 },
    secondary_color: [3]u8 = .{ 255, 255, 255 },
    zoom_level: f32 = 1.0,
    pan_x: f32 = 0,
    pan_y: f32 = 0,
    is_drawing: bool = false,
    last_draw_x: i32 = 0,
    last_draw_y: i32 = 0,
    brush_size: i32 = 3,
    show_grid: bool = false,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) AppState {
        return .{ .allocator = allocator };
    }

    fn initCanvas(self: *AppState) !void {
        const pixel_count: usize = @intCast(self.canvas_width * self.canvas_height * 4);
        self.canvas_pixels = try self.allocator.alloc(u8, pixel_count);
        // Fill with white (opaque)
        const pixels = self.canvas_pixels.?;
        var i: usize = 0;
        while (i < pixel_count) : (i += 4) {
            pixels[i] = 255; // R
            pixels[i + 1] = 255; // G
            pixels[i + 2] = 255; // B
            pixels[i + 3] = 255; // A
        }
        self.canvas_dirty = true;
    }

    fn uploadTexture(self: *AppState) void {
        if (self.canvas_pixels) |pixels| {
            if (self.canvas_texture) |tex| {
                rl.updateTexture(tex, @ptrCast(pixels.ptr));
            } else {
                var img = rl.Image{
                    .data = @ptrCast(pixels.ptr),
                    .width = self.canvas_width,
                    .height = self.canvas_height,
                    .mipmaps = 1,
                    .format = .uncompressed_r8g8b8a8,
                };
                self.canvas_texture = rl.loadTextureFromImage(img) catch null;
                _ = &img;
            }
            self.canvas_dirty = false;
        }
    }

    fn deinit(self: *AppState) void {
        if (self.canvas_texture) |tex| tex.unload();
        if (self.canvas_pixels) |pixels| self.allocator.free(pixels);
    }

    fn setPixel(self: *AppState, x: i32, y: i32, r: u8, g: u8, b: u8, a: u8) void {
        if (x < 0 or y < 0 or x >= self.canvas_width or y >= self.canvas_height) return;
        if (self.canvas_pixels) |pixels| {
            const idx: usize = @intCast((y * self.canvas_width + x) * 4);
            pixels[idx] = r;
            pixels[idx + 1] = g;
            pixels[idx + 2] = b;
            pixels[idx + 3] = a;
            self.canvas_dirty = true;
        }
    }

    fn drawBrushStroke(self: *AppState, cx: i32, cy: i32) void {
        const half = @divTrunc(self.brush_size, @as(i32, 2));
        var dy: i32 = -half;
        while (dy <= half) : (dy += 1) {
            var dx: i32 = -half;
            while (dx <= half) : (dx += 1) {
                self.setPixel(cx + dx, cy + dy, self.primary_color[0], self.primary_color[1], self.primary_color[2], 255);
            }
        }
    }

    fn drawLineTo(self: *AppState, x0: i32, y0: i32, x1: i32, y1: i32) void {
        var sx: i32 = if (x0 < x1) @as(i32, 1) else @as(i32, -1);
        var sy: i32 = if (y0 < y1) @as(i32, 1) else @as(i32, -1);
        _ = &sx;
        _ = &sy;
        var dx_val: i32 = if (x1 > x0) x1 - x0 else x0 - x1;
        var dy_val: i32 = if (y1 > y0) y1 - y0 else y0 - y1;
        _ = &dx_val;
        _ = &dy_val;
        var err = dx_val - dy_val;
        var cx = x0;
        var cy = y0;
        while (true) {
            self.drawBrushStroke(cx, cy);
            if (cx == x1 and cy == y1) break;
            const e2 = err * 2;
            if (e2 > -dy_val) {
                err -= dy_val;
                cx += sx;
            }
            if (e2 < dx_val) {
                err += dx_val;
                cy += sy;
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true, .vsync_hint = true });
    rl.initWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, WINDOW_TITLE);
    defer rl.closeWindow();
    rl.setWindowMinSize(MIN_WIDTH, MIN_HEIGHT);
    rl.setTargetFPS(60);

    var app = AppState.init(allocator);
    defer app.deinit();
    try app.initCanvas();

    while (!rl.windowShouldClose()) {
        handleInput(&app);

        if (app.canvas_dirty) {
            app.uploadTexture();
        }

        rl.beginDrawing();
        rl.clearBackground(UI_BG);

        const screen_w = rl.getScreenWidth();
        const screen_h = rl.getScreenHeight();

        drawMenuBar(screen_w);
        drawToolbar(screen_w, &app);
        drawCanvas(&app, screen_w, screen_h);
        drawSidebar(&app, screen_w, screen_h);
        drawStatusBar(&app, screen_w, screen_h);

        rl.endDrawing();
    }
}

fn handleInput(app: *AppState) void {
    const screen_w = rl.getScreenWidth();
    const screen_h = rl.getScreenHeight();
    const canvas_area_w: f32 = @floatFromInt(screen_w - SIDEBAR_WIDTH);
    const canvas_area_h: f32 = @floatFromInt(screen_h - CANVAS_Y - STATUSBAR_HEIGHT);
    const offset_x = (canvas_area_w - @as(f32, @floatFromInt(app.canvas_width)) * app.zoom_level) / 2.0 + app.pan_x;
    const offset_y = (canvas_area_h - @as(f32, @floatFromInt(app.canvas_height)) * app.zoom_level) / 2.0 + app.pan_y;

    const mouse = rl.getMousePosition();
    const canvas_mouse_x: i32 = @intFromFloat((mouse.x - offset_x) / app.zoom_level);
    const canvas_mouse_y: i32 = @intFromFloat((mouse.y - @as(f32, CANVAS_Y) - offset_y) / app.zoom_level);

    const in_canvas_area = mouse.x >= 0 and mouse.x < canvas_area_w and
        mouse.y >= CANVAS_Y and mouse.y < @as(f32, @floatFromInt(screen_h - STATUSBAR_HEIGHT));

    // Zoom with mouse wheel
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0 and in_canvas_area) {
        if (wheel > 0) {
            app.zoom_level = @min(app.zoom_level * 1.1, 32.0);
        } else {
            app.zoom_level = @max(app.zoom_level / 1.1, 0.1);
        }
    }

    // Pan with middle mouse button
    if (rl.isMouseButtonDown(.middle)) {
        const delta = rl.getMouseDelta();
        app.pan_x += delta.x;
        app.pan_y += delta.y;
    }

    // Drawing with brush/pencil/eraser
    if (app.current_tool == .brush or app.current_tool == .pencil or app.current_tool == .eraser) {
        if (rl.isMouseButtonPressed(.left) and in_canvas_area) {
            app.is_drawing = true;
            app.last_draw_x = canvas_mouse_x;
            app.last_draw_y = canvas_mouse_y;
            if (app.current_tool == .eraser) {
                const saved = app.primary_color;
                app.primary_color = app.secondary_color;
                app.drawBrushStroke(canvas_mouse_x, canvas_mouse_y);
                app.primary_color = saved;
            } else {
                app.drawBrushStroke(canvas_mouse_x, canvas_mouse_y);
            }
        }
        if (rl.isMouseButtonDown(.left) and app.is_drawing) {
            if (app.current_tool == .eraser) {
                const saved = app.primary_color;
                app.primary_color = app.secondary_color;
                app.drawLineTo(app.last_draw_x, app.last_draw_y, canvas_mouse_x, canvas_mouse_y);
                app.primary_color = saved;
            } else {
                app.drawLineTo(app.last_draw_x, app.last_draw_y, canvas_mouse_x, canvas_mouse_y);
            }
            app.last_draw_x = canvas_mouse_x;
            app.last_draw_y = canvas_mouse_y;
        }
        if (rl.isMouseButtonReleased(.left)) {
            app.is_drawing = false;
        }
    }

    // Keyboard shortcuts
    if (rl.isKeyPressed(.b)) app.current_tool = .brush;
    if (rl.isKeyPressed(.e)) app.current_tool = .eraser;
    if (rl.isKeyPressed(.p)) app.current_tool = .pencil;
    if (rl.isKeyPressed(.g)) app.current_tool = .gradient;
    if (rl.isKeyPressed(.k)) app.current_tool = .bucket;
    if (rl.isKeyPressed(.l)) app.current_tool = .line;
    if (rl.isKeyPressed(.s)) app.current_tool = .rectangle_select;
    if (rl.isKeyPressed(.m)) app.current_tool = .move;
    if (rl.isKeyPressed(.t)) app.current_tool = .text;
    if (rl.isKeyPressed(.z)) app.current_tool = .zoom;
    if (rl.isKeyPressed(.o)) app.current_tool = .ellipse;
    if (rl.isKeyPressed(.r)) app.current_tool = .rectangle;

    // Brush size
    if (rl.isKeyPressed(.kp_add) or rl.isKeyPressed(.right_bracket)) {
        app.brush_size = @min(app.brush_size + 1, 100);
    }
    if (rl.isKeyPressed(.kp_subtract) or rl.isKeyPressed(.left_bracket)) {
        app.brush_size = @max(app.brush_size - 1, 1);
    }
}

fn drawMenuBar(screen_w: i32) void {
    rl.drawRectangle(0, 0, screen_w, MENUBAR_HEIGHT, UI_PANEL);
    rl.drawLine(0, MENUBAR_HEIGHT, screen_w, MENUBAR_HEIGHT, UI_BORDER);

    const menus = [_][:0]const u8{ "File", "Edit", "View", "Image", "Layers", "Adjustments", "Effects", "Window", "Help" };
    var x: i32 = 8;
    for (menus) |label| {
        const w = rl.measureText(label, 14) + 16;
        rl.drawText(label, x + 8, 5, 14, UI_TEXT);
        x += w;
    }
}

fn drawToolbar(screen_w: i32, app: *AppState) void {
    rl.drawRectangle(0, TOOLBAR_Y, screen_w, TOOLBAR_HEIGHT, UI_PANEL);
    rl.drawLine(0, TOOLBAR_Y + TOOLBAR_HEIGHT, screen_w, TOOLBAR_Y + TOOLBAR_HEIGHT, UI_BORDER);

    var x: i32 = 4;
    const tool_count = @typeInfo(ToolKind).@"enum".fields.len;
    for (0..tool_count) |i| {
        const tool: ToolKind = @enumFromInt(i);
        const btn_w: i32 = 50;
        const btn_h: i32 = 30;
        const btn_y = TOOLBAR_Y + 5;

        const mouse = rl.getMousePosition();
        const mx: i32 = @intFromFloat(mouse.x);
        const my: i32 = @intFromFloat(mouse.y);
        const hovered = mx >= x and mx < x + btn_w and my >= btn_y and my < btn_y + btn_h;
        const selected = app.current_tool == tool;

        const bg = if (selected) UI_ACTIVE else if (hovered) UI_HOVER else UI_PANEL;
        rl.drawRectangle(x, btn_y, btn_w, btn_h, bg);

        const label = tool_names[i];
        const tw = rl.measureText(label, 10);
        rl.drawText(label, x + @divTrunc(btn_w - tw, 2), btn_y + 10, 10, if (selected) rl.Color.white else UI_TEXT);

        if (hovered and rl.isMouseButtonPressed(.left)) {
            app.current_tool = tool;
        }

        x += btn_w + 2;
    }

    // Brush size indicator
    const size_text_buf: [32]u8 = undefined;
    _ = size_text_buf;
    rl.drawText("Size:", x + 10, TOOLBAR_Y + 13, 12, UI_TEXT_DIM);
    x += 46;

    // Draw brush size as a filled circle preview
    rl.drawCircle(x + 10, TOOLBAR_Y + 20, @floatFromInt(@divTrunc(app.brush_size, 2) + 1), rl.Color.init(app.primary_color[0], app.primary_color[1], app.primary_color[2], 255));
}

fn drawCanvas(app: *AppState, screen_w: i32, screen_h: i32) void {
    const canvas_area_x: i32 = 0;
    const canvas_area_y: i32 = CANVAS_Y;
    const canvas_area_w: i32 = screen_w - SIDEBAR_WIDTH;
    const canvas_area_h: i32 = screen_h - CANVAS_Y - STATUSBAR_HEIGHT;

    // Canvas background
    rl.drawRectangle(canvas_area_x, canvas_area_y, canvas_area_w, canvas_area_h, CANVAS_BG);

    // Calculate canvas position (centered with pan offset)
    const caw_f: f32 = @floatFromInt(canvas_area_w);
    const cah_f: f32 = @floatFromInt(canvas_area_h);
    const scaled_w: f32 = @as(f32, @floatFromInt(app.canvas_width)) * app.zoom_level;
    const scaled_h: f32 = @as(f32, @floatFromInt(app.canvas_height)) * app.zoom_level;
    const draw_x: f32 = (caw_f - scaled_w) / 2.0 + app.pan_x;
    const draw_y: f32 = (cah_f - scaled_h) / 2.0 + app.pan_y + @as(f32, CANVAS_Y);

    // Draw checkerboard pattern behind canvas (transparency indicator)
    const checker_size: i32 = @max(@as(i32, @intFromFloat(8.0 * app.zoom_level)), 4);
    const cx_start: i32 = @intFromFloat(@max(draw_x, @as(f32, @floatFromInt(canvas_area_x))));
    const cy_start: i32 = @intFromFloat(@max(draw_y, @as(f32, @floatFromInt(canvas_area_y))));
    const cx_end: i32 = @intFromFloat(@min(draw_x + scaled_w, @as(f32, @floatFromInt(canvas_area_x + canvas_area_w))));
    const cy_end: i32 = @intFromFloat(@min(draw_y + scaled_h, @as(f32, @floatFromInt(canvas_area_y + canvas_area_h))));

    var cy: i32 = cy_start;
    while (cy < cy_end) {
        var cx: i32 = cx_start;
        while (cx < cx_end) {
            const ci = @divTrunc(cx - cx_start, checker_size);
            const cj = @divTrunc(cy - cy_start, checker_size);
            const is_light = @mod(ci + cj, 2) == 0;
            const cw = @min(checker_size, cx_end - cx);
            const ch = @min(checker_size, cy_end - cy);
            rl.drawRectangle(cx, cy, cw, ch, if (is_light) CHECKER_LIGHT else CHECKER_DARK);
            cx += checker_size;
        }
        cy += checker_size;
    }

    // Draw the canvas texture
    if (app.canvas_texture) |tex| {
        const source = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(app.canvas_width),
            .height = @floatFromInt(app.canvas_height),
        };
        const dest = rl.Rectangle{
            .x = draw_x,
            .y = draw_y,
            .width = scaled_w,
            .height = scaled_h,
        };
        rl.drawTexturePro(tex, source, dest, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
    }

    // Canvas border
    rl.drawRectangleLinesEx(.{
        .x = draw_x - 1,
        .y = draw_y - 1,
        .width = scaled_w + 2,
        .height = scaled_h + 2,
    }, 1.0, UI_BORDER);

    // Separator line between canvas and sidebar
    rl.drawLine(canvas_area_x + canvas_area_w, canvas_area_y, canvas_area_x + canvas_area_w, canvas_area_y + canvas_area_h, UI_BORDER);
}

fn drawSidebar(app: *AppState, screen_w: i32, screen_h: i32) void {
    const sidebar_x = screen_w - SIDEBAR_WIDTH;
    const sidebar_y = CANVAS_Y;
    const sidebar_h = screen_h - CANVAS_Y - STATUSBAR_HEIGHT;

    rl.drawRectangle(sidebar_x, sidebar_y, SIDEBAR_WIDTH, sidebar_h, UI_PANEL);

    // --- Color Panel ---
    rl.drawText("Colors", sidebar_x + 8, sidebar_y + 6, 13, UI_TEXT);
    rl.drawLine(sidebar_x, sidebar_y + 22, sidebar_x + SIDEBAR_WIDTH, sidebar_y + 22, UI_BORDER);

    // Primary/secondary color swatches
    const swatch_x = sidebar_x + 12;
    const swatch_y = sidebar_y + 30;
    // Secondary (behind)
    rl.drawRectangle(swatch_x + 20, swatch_y + 20, 36, 36, rl.Color.init(app.secondary_color[0], app.secondary_color[1], app.secondary_color[2], 255));
    rl.drawRectangleLinesEx(.{ .x = @floatFromInt(swatch_x + 20), .y = @floatFromInt(swatch_y + 20), .width = 36, .height = 36 }, 1.0, UI_BORDER);
    // Primary (front)
    rl.drawRectangle(swatch_x, swatch_y, 36, 36, rl.Color.init(app.primary_color[0], app.primary_color[1], app.primary_color[2], 255));
    rl.drawRectangleLinesEx(.{ .x = @floatFromInt(swatch_x), .y = @floatFromInt(swatch_y), .width = 36, .height = 36 }, 1.0, rl.Color.white);

    // Color palette
    const palette_colors = [_][3]u8{
        .{ 0, 0, 0 },       .{ 127, 127, 127 }, .{ 136, 0, 21 },     .{ 237, 28, 36 },
        .{ 255, 127, 39 },   .{ 255, 242, 0 },   .{ 34, 177, 76 },    .{ 0, 162, 232 },
        .{ 63, 72, 204 },    .{ 163, 73, 164 },   .{ 255, 255, 255 },  .{ 195, 195, 195 },
        .{ 185, 122, 87 },   .{ 255, 174, 201 },  .{ 255, 201, 14 },   .{ 239, 228, 176 },
        .{ 181, 230, 29 },   .{ 153, 217, 234 },  .{ 112, 146, 190 },  .{ 200, 191, 231 },
    };

    const pal_x = sidebar_x + 70;
    const pal_y = sidebar_y + 30;
    for (palette_colors, 0..) |pc, idx| {
        const col: i32 = @intCast(idx % 10);
        const row: i32 = @intCast(idx / 10);
        const px = pal_x + col * 13;
        const py = pal_y + row * 13;
        rl.drawRectangle(px, py, 12, 12, rl.Color.init(pc[0], pc[1], pc[2], 255));

        const mouse = rl.getMousePosition();
        const mx: i32 = @intFromFloat(mouse.x);
        const my: i32 = @intFromFloat(mouse.y);
        if (mx >= px and mx < px + 12 and my >= py and my < py + 12) {
            rl.drawRectangleLinesEx(.{ .x = @floatFromInt(px), .y = @floatFromInt(py), .width = 12, .height = 12 }, 1.0, rl.Color.white);
            if (rl.isMouseButtonPressed(.left)) {
                app.primary_color = pc;
            } else if (rl.isMouseButtonPressed(.right)) {
                app.secondary_color = pc;
            }
        }
    }

    // --- Layers Panel ---
    const layers_y = sidebar_y + COLOR_PANEL_HEIGHT;
    rl.drawLine(sidebar_x, layers_y, sidebar_x + SIDEBAR_WIDTH, layers_y, UI_BORDER);
    rl.drawText("Layers", sidebar_x + 8, layers_y + 6, 13, UI_TEXT);
    rl.drawLine(sidebar_x, layers_y + 22, sidebar_x + SIDEBAR_WIDTH, layers_y + 22, UI_BORDER);

    // Layer entry (single layer for now)
    const layer_entry_y = layers_y + 26;
    rl.drawRectangle(sidebar_x + 4, layer_entry_y, SIDEBAR_WIDTH - 8, 24, UI_ACTIVE);
    rl.drawText("Background", sidebar_x + 28, layer_entry_y + 6, 12, rl.Color.white);

    // Eye icon (visibility)
    rl.drawText("*", sidebar_x + 10, layer_entry_y + 5, 14, rl.Color.white);

    // --- History Panel ---
    const history_y = layers_y + 100;
    rl.drawLine(sidebar_x, history_y, sidebar_x + SIDEBAR_WIDTH, history_y, UI_BORDER);
    rl.drawText("History", sidebar_x + 8, history_y + 6, 13, UI_TEXT);
    rl.drawLine(sidebar_x, history_y + 22, sidebar_x + SIDEBAR_WIDTH, history_y + 22, UI_BORDER);
    rl.drawText("New Image", sidebar_x + 10, history_y + 28, 11, UI_TEXT_DIM);
}

fn drawStatusBar(app: *AppState, screen_w: i32, screen_h: i32) void {
    const bar_y = screen_h - STATUSBAR_HEIGHT;
    rl.drawRectangle(0, bar_y, screen_w, STATUSBAR_HEIGHT, UI_PANEL);
    rl.drawLine(0, bar_y, screen_w, bar_y, UI_BORDER);

    // Canvas size
    var buf: [128]u8 = undefined;
    const size_str = std.fmt.bufPrintZ(&buf, "{d}x{d}px", .{ app.canvas_width, app.canvas_height }) catch "?";
    rl.drawText(size_str, 8, bar_y + 5, 12, UI_TEXT_DIM);

    // Zoom level
    const zoom_pct: i32 = @intFromFloat(app.zoom_level * 100.0);
    const zoom_str = std.fmt.bufPrintZ(&buf, "Zoom: {d}%%", .{zoom_pct}) catch "?";
    rl.drawText(zoom_str, 140, bar_y + 5, 12, UI_TEXT_DIM);

    // Current tool
    const tool_idx: usize = @intFromEnum(app.current_tool);
    const tool_label = tool_names[tool_idx];
    rl.drawText(tool_label, 260, bar_y + 5, 12, UI_TEXT_DIM);

    // Mouse position
    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);
    const pos_str = std.fmt.bufPrintZ(&buf, "({d}, {d})", .{ mx, my }) catch "?";
    const pos_w = rl.measureText(pos_str, 12);
    rl.drawText(pos_str, screen_w - pos_w - 8, bar_y + 5, 12, UI_TEXT_DIM);
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
