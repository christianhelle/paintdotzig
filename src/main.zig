const std = @import("std");
const rl = @import("raylib");
const Bmp = @import("formats/bmp.zig").Bmp;
const CoreImage = @import("core/image.zig").Image;
const CoreColor = @import("core/color.zig").Color;

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
const MENU_ITEM_HEIGHT = 22;
const MENU_WIDTH = 200;

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
const UI_DROPDOWN = rl.Color.init(27, 27, 28, 255);
const UI_SEPARATOR = rl.Color.init(51, 51, 51, 255);
const UI_DIALOG_BG = rl.Color.init(50, 50, 53, 255);
const UI_DIALOG_BORDER = rl.Color.init(0, 122, 204, 255);
const UI_INPUT_BG = rl.Color.init(30, 30, 30, 255);
const UI_ERROR_TEXT = rl.Color.init(255, 80, 80, 255);
const UI_SUCCESS_TEXT = rl.Color.init(80, 255, 80, 255);

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

const MenuId = enum {
    none,
    file,
    edit,
    view,
    image,
    layers,
    adjustments,
    effects,
    window,
    help,
};

const menu_labels = [_][:0]const u8{ "File", "Edit", "View", "Image", "Layers", "Adjustments", "Effects", "Window", "Help" };
const menu_ids = [_]MenuId{ .file, .edit, .view, .image, .layers, .adjustments, .effects, .window, .help };

const MenuItem = struct {
    label: [:0]const u8,
    shortcut: [:0]const u8 = "",
    is_separator: bool = false,
    enabled: bool = true,
};

const SEPARATOR = MenuItem{ .label = "", .is_separator = true };

const file_menu_items = [_]MenuItem{
    .{ .label = "New", .shortcut = "Ctrl+N" },
    .{ .label = "Open...", .shortcut = "Ctrl+O" },
    SEPARATOR,
    .{ .label = "Save", .shortcut = "Ctrl+S" },
    .{ .label = "Save As...", .shortcut = "Ctrl+Shift+S" },
    SEPARATOR,
    .{ .label = "Exit", .shortcut = "Alt+F4" },
};

const edit_menu_items = [_]MenuItem{
    .{ .label = "Undo", .shortcut = "Ctrl+Z" },
    .{ .label = "Redo", .shortcut = "Ctrl+Y" },
    SEPARATOR,
    .{ .label = "Cut", .shortcut = "Ctrl+X" },
    .{ .label = "Copy", .shortcut = "Ctrl+C" },
    .{ .label = "Paste", .shortcut = "Ctrl+V" },
    SEPARATOR,
    .{ .label = "Select All", .shortcut = "Ctrl+A" },
    .{ .label = "Deselect", .shortcut = "Ctrl+D" },
    .{ .label = "Invert Selection" },
};

const view_menu_items = [_]MenuItem{
    .{ .label = "Zoom In", .shortcut = "Ctrl++" },
    .{ .label = "Zoom Out", .shortcut = "Ctrl+-" },
    .{ .label = "Zoom to Fit", .shortcut = "Ctrl+0" },
    .{ .label = "Actual Size", .shortcut = "Ctrl+1" },
    SEPARATOR,
    .{ .label = "Toggle Grid", .shortcut = "Ctrl+G" },
};

const image_menu_items = [_]MenuItem{
    .{ .label = "Resize..." },
    .{ .label = "Canvas Size..." },
    SEPARATOR,
    .{ .label = "Flip Horizontal" },
    .{ .label = "Flip Vertical" },
    SEPARATOR,
    .{ .label = "Rotate 90 CW" },
    .{ .label = "Rotate 90 CCW" },
    .{ .label = "Rotate 180" },
    SEPARATOR,
    .{ .label = "Flatten" },
};

const layers_menu_items = [_]MenuItem{
    .{ .label = "Add New Layer", .shortcut = "Ctrl+Shift+N" },
    .{ .label = "Delete Layer" },
    .{ .label = "Duplicate Layer" },
    SEPARATOR,
    .{ .label = "Merge Down" },
    .{ .label = "Flatten Image" },
};

const adjustments_menu_items = [_]MenuItem{
    .{ .label = "Brightness/Contrast" },
    .{ .label = "Hue/Saturation" },
    .{ .label = "Levels" },
    SEPARATOR,
    .{ .label = "Invert Colors", .shortcut = "Ctrl+I" },
    .{ .label = "Grayscale" },
    .{ .label = "Sepia" },
    .{ .label = "Posterize" },
    .{ .label = "Threshold" },
};

const effects_menu_items = [_]MenuItem{
    .{ .label = "Gaussian Blur" },
    .{ .label = "Sharpen" },
    .{ .label = "Add Noise" },
    .{ .label = "Emboss" },
};

const DialogKind = enum {
    none,
    file_open,
    file_save_as,
    new_image,
};

const MAX_PATH_LEN = 512;
const MAX_STATUS_LEN = 128;

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

    // Menu state
    open_menu: MenuId = .none,

    // Dialog state
    active_dialog: DialogKind = .none,
    path_buf: [MAX_PATH_LEN]u8 = [_]u8{0} ** MAX_PATH_LEN,
    path_len: usize = 0,
    dialog_status: [MAX_STATUS_LEN]u8 = [_]u8{0} ** MAX_STATUS_LEN,
    dialog_status_len: usize = 0,
    dialog_status_is_error: bool = false,
    new_width_buf: [8]u8 = [_]u8{0} ** 8,
    new_width_len: usize = 0,
    new_height_buf: [8]u8 = [_]u8{0} ** 8,
    new_height_len: usize = 0,

    // File tracking
    current_file_path: [MAX_PATH_LEN]u8 = [_]u8{0} ** MAX_PATH_LEN,
    current_file_len: usize = 0,
    has_unsaved_changes: bool = false,

    fn init(allocator: std.mem.Allocator) AppState {
        var state = AppState{ .allocator = allocator };
        // Pre-fill new image defaults
        const w_default = "800";
        const h_default = "600";
        @memcpy(state.new_width_buf[0..w_default.len], w_default);
        state.new_width_len = w_default.len;
        @memcpy(state.new_height_buf[0..h_default.len], h_default);
        state.new_height_len = h_default.len;
        return state;
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

    fn setDialogStatus(self: *AppState, msg: []const u8, is_error: bool) void {
        const len = @min(msg.len, MAX_STATUS_LEN);
        @memcpy(self.dialog_status[0..len], msg[0..len]);
        self.dialog_status_len = len;
        self.dialog_status_is_error = is_error;
    }

    fn clearDialogState(self: *AppState) void {
        self.path_buf = [_]u8{0} ** MAX_PATH_LEN;
        self.path_len = 0;
        self.dialog_status_len = 0;
        self.dialog_status_is_error = false;
    }

    fn openFile(self: *AppState) void {
        if (self.path_len == 0) {
            self.setDialogStatus("Please enter a file path", true);
            return;
        }
        const path = self.path_buf[0..self.path_len];

        // Determine format by extension
        if (endsWithIgnoreCase(path, ".bmp")) {
            self.openBmpFile(path);
        } else {
            self.setDialogStatus("Unsupported format (use .bmp)", true);
        }
    }

    fn openBmpFile(self: *AppState, path: []const u8) void {
        var core_img = Bmp.readFile(self.allocator, path) catch {
            self.setDialogStatus("Failed to open file", true);
            return;
        };
        defer core_img.deinit();

        // Replace canvas with loaded image
        self.replaceCanvas(@intCast(core_img.width), @intCast(core_img.height)) catch {
            self.setDialogStatus("Out of memory", true);
            return;
        };

        // Copy pixels from CoreImage (Color structs) to RGBA byte buffer
        if (self.canvas_pixels) |pixels| {
            for (core_img.pixels, 0..) |color, i| {
                const idx = i * 4;
                pixels[idx] = color.r;
                pixels[idx + 1] = color.g;
                pixels[idx + 2] = color.b;
                pixels[idx + 3] = color.a;
            }
            self.canvas_dirty = true;
        }

        // Update current file path and window title
        @memcpy(self.current_file_path[0..path.len], path);
        self.current_file_len = path.len;
        self.has_unsaved_changes = false;
        self.updateWindowTitle();
        self.active_dialog = .none;
        self.zoom_level = 1.0;
        self.pan_x = 0;
        self.pan_y = 0;
    }

    fn saveFile(self: *AppState) void {
        if (self.current_file_len == 0) {
            // No current file - show Save As dialog
            self.active_dialog = .file_save_as;
            self.clearDialogState();
            return;
        }
        const path = self.current_file_path[0..self.current_file_len];
        self.saveToPath(path);
    }

    fn saveAsFile(self: *AppState) void {
        if (self.path_len == 0) {
            self.setDialogStatus("Please enter a file path", true);
            return;
        }
        const path = self.path_buf[0..self.path_len];
        self.saveToPath(path);
    }

    fn saveToPath(self: *AppState, path: []const u8) void {
        if (!endsWithIgnoreCase(path, ".bmp")) {
            self.setDialogStatus("Unsupported format (use .bmp)", true);
            return;
        }

        if (self.canvas_pixels == null) {
            self.setDialogStatus("No image to save", true);
            return;
        }
        const pixels = self.canvas_pixels.?;

        // Build CoreImage from pixel buffer
        const w: u32 = @intCast(self.canvas_width);
        const h: u32 = @intCast(self.canvas_height);
        const pixel_count = @as(usize, w) * @as(usize, h);
        const core_pixels = self.allocator.alloc(CoreColor, pixel_count) catch {
            self.setDialogStatus("Out of memory", true);
            return;
        };
        defer self.allocator.free(core_pixels);

        for (0..pixel_count) |i| {
            const idx = i * 4;
            core_pixels[i] = CoreColor{
                .r = pixels[idx],
                .g = pixels[idx + 1],
                .b = pixels[idx + 2],
                .a = pixels[idx + 3],
            };
        }

        var img = CoreImage{
            .width = w,
            .height = h,
            .pixels = core_pixels,
            .allocator = self.allocator,
        };

        Bmp.writeFile(&img, path) catch {
            self.setDialogStatus("Failed to write file", true);
            return;
        };

        // Update current file path
        @memcpy(self.current_file_path[0..path.len], path);
        self.current_file_len = path.len;
        self.has_unsaved_changes = false;
        self.updateWindowTitle();
        self.active_dialog = .none;
    }

    fn replaceCanvas(self: *AppState, new_w: i32, new_h: i32) !void {
        if (self.canvas_texture) |tex| tex.unload();
        self.canvas_texture = null;
        if (self.canvas_pixels) |pixels| self.allocator.free(pixels);

        self.canvas_width = new_w;
        self.canvas_height = new_h;
        const pixel_count: usize = @intCast(new_w * new_h * 4);
        self.canvas_pixels = try self.allocator.alloc(u8, pixel_count);
        self.canvas_dirty = true;
    }

    fn newImage(self: *AppState) void {
        const w_str = self.new_width_buf[0..self.new_width_len];
        const h_str = self.new_height_buf[0..self.new_height_len];
        const w = std.fmt.parseInt(i32, w_str, 10) catch {
            self.setDialogStatus("Invalid width", true);
            return;
        };
        const h = std.fmt.parseInt(i32, h_str, 10) catch {
            self.setDialogStatus("Invalid height", true);
            return;
        };
        if (w < 1 or w > 16384 or h < 1 or h > 16384) {
            self.setDialogStatus("Size must be 1-16384", true);
            return;
        }

        self.replaceCanvas(w, h) catch {
            self.setDialogStatus("Out of memory", true);
            return;
        };

        // Fill with white
        if (self.canvas_pixels) |pixels| {
            var i: usize = 0;
            const count: usize = @intCast(w * h * 4);
            while (i < count) : (i += 4) {
                pixels[i] = 255;
                pixels[i + 1] = 255;
                pixels[i + 2] = 255;
                pixels[i + 3] = 255;
            }
        }

        self.current_file_len = 0;
        self.has_unsaved_changes = false;
        self.updateWindowTitle();
        self.active_dialog = .none;
        self.zoom_level = 1.0;
        self.pan_x = 0;
        self.pan_y = 0;
    }

    fn updateWindowTitle(self: *AppState) void {
        var title_buf: [MAX_PATH_LEN + 64]u8 = undefined;
        const title = if (self.current_file_len > 0)
            std.fmt.bufPrintZ(&title_buf, "{s}{s} - Paint.Zig", .{
                if (self.has_unsaved_changes) "*" else "",
                self.current_file_path[0..self.current_file_len],
            }) catch WINDOW_TITLE
        else
            std.fmt.bufPrintZ(&title_buf, "{s}Untitled - Paint.Zig", .{
                if (self.has_unsaved_changes) "*" else "",
            }) catch WINDOW_TITLE;
        rl.setWindowTitle(title);
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

        drawToolbar(screen_w, &app);
        drawCanvas(&app, screen_w, screen_h);
        drawSidebar(&app, screen_w, screen_h);
        drawStatusBar(&app, screen_w, screen_h);
        drawMenuBar(screen_w, &app);

        if (app.active_dialog != .none) {
            drawDialog(&app, screen_w, screen_h);
        }

        rl.endDrawing();
    }
}

fn handleInput(app: *AppState) void {
    // If a dialog is open, only handle dialog input
    if (app.active_dialog != .none) {
        handleDialogInput(app);
        return;
    }

    // Close menu if clicking outside
    if (rl.isMouseButtonPressed(.left) and app.open_menu != .none) {
        const mouse = rl.getMousePosition();
        if (mouse.y > MENUBAR_HEIGHT) {
            // Check if click is within the dropdown area
            if (!isMouseInDropdown(app)) {
                app.open_menu = .none;
            }
        }
    }

    // Handle menu item clicks
    if (app.open_menu != .none) {
        handleMenuClick(app);
        return;
    }

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
            app.has_unsaved_changes = true;
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

    const ctrl = rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control);
    const shift = rl.isKeyDown(.left_shift) or rl.isKeyDown(.right_shift);

    // Menu keyboard shortcuts
    if (ctrl) {
        if (rl.isKeyPressed(.n)) {
            app.active_dialog = .new_image;
            app.clearDialogState();
            return;
        }
        if (rl.isKeyPressed(.o)) {
            app.active_dialog = .file_open;
            app.clearDialogState();
            return;
        }
        if (rl.isKeyPressed(.s)) {
            if (shift) {
                app.active_dialog = .file_save_as;
                app.clearDialogState();
            } else {
                app.saveFile();
            }
            return;
        }
        // View shortcuts
        if (rl.isKeyPressed(.equal)) {
            app.zoom_level = @min(app.zoom_level * 1.25, 32.0);
            return;
        }
        if (rl.isKeyPressed(.minus)) {
            app.zoom_level = @max(app.zoom_level / 1.25, 0.1);
            return;
        }
        if (rl.isKeyPressed(.zero)) {
            zoomToFit(app);
            return;
        }
        if (rl.isKeyPressed(.one)) {
            app.zoom_level = 1.0;
            app.pan_x = 0;
            app.pan_y = 0;
            return;
        }
        if (rl.isKeyPressed(.g)) {
            app.show_grid = !app.show_grid;
            return;
        }
    }

    // Tool shortcuts (only when Ctrl not held)
    if (!ctrl) {
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
    }

    // Brush size
    if (rl.isKeyPressed(.kp_add) or rl.isKeyPressed(.right_bracket)) {
        app.brush_size = @min(app.brush_size + 1, 100);
    }
    if (rl.isKeyPressed(.kp_subtract) or rl.isKeyPressed(.left_bracket)) {
        app.brush_size = @max(app.brush_size - 1, 1);
    }
}

fn drawMenuBar(screen_w: i32, app: *AppState) void {
    rl.drawRectangle(0, 0, screen_w, MENUBAR_HEIGHT, UI_PANEL);
    rl.drawLine(0, MENUBAR_HEIGHT, screen_w, MENUBAR_HEIGHT, UI_BORDER);

    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);

    var x: i32 = 8;
    for (menu_labels, 0..) |label, i| {
        const w = rl.measureText(label, 14) + 16;
        const hovered = mx >= x and mx < x + w and my >= 0 and my < MENUBAR_HEIGHT;
        const is_open = app.open_menu == menu_ids[i];

        if (is_open or hovered) {
            rl.drawRectangle(x, 0, w, MENUBAR_HEIGHT, if (is_open) UI_ACTIVE else UI_HOVER);
        }

        rl.drawText(label, x + 8, 5, 14, UI_TEXT);

        // Open menu on click, or switch if another menu is already open
        if (hovered and rl.isMouseButtonPressed(.left)) {
            app.open_menu = if (is_open) .none else menu_ids[i];
        } else if (hovered and app.open_menu != .none and !is_open) {
            app.open_menu = menu_ids[i];
        }

        // Draw dropdown if this menu is open
        if (is_open) {
            const items = getMenuItems(menu_ids[i]);
            drawDropdown(x, MENUBAR_HEIGHT, items);
        }

        x += w;
    }
}

fn getMenuItems(menu: MenuId) []const MenuItem {
    return switch (menu) {
        .file => &file_menu_items,
        .edit => &edit_menu_items,
        .view => &view_menu_items,
        .image => &image_menu_items,
        .layers => &layers_menu_items,
        .adjustments => &adjustments_menu_items,
        .effects => &effects_menu_items,
        else => &[_]MenuItem{},
    };
}

fn drawDropdown(x: i32, y: i32, items: []const MenuItem) void {
    // Calculate dropdown height
    var total_h: i32 = 4; // padding
    for (items) |item| {
        total_h += if (item.is_separator) 7 else MENU_ITEM_HEIGHT;
    }
    total_h += 4;

    // Drop shadow
    rl.drawRectangle(x + 2, y + 2, MENU_WIDTH, total_h, rl.Color.init(0, 0, 0, 80));
    // Background
    rl.drawRectangle(x, y, MENU_WIDTH, total_h, UI_DROPDOWN);
    rl.drawRectangleLinesEx(.{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = MENU_WIDTH,
        .height = @floatFromInt(total_h),
    }, 1.0, UI_BORDER);

    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);

    var item_y: i32 = y + 4;
    for (items) |item| {
        if (item.is_separator) {
            rl.drawLine(x + 4, item_y + 3, x + MENU_WIDTH - 4, item_y + 3, UI_SEPARATOR);
            item_y += 7;
            continue;
        }

        const hovered = mx >= x and mx < x + MENU_WIDTH and
            my >= item_y and my < item_y + MENU_ITEM_HEIGHT and item.enabled;

        if (hovered) {
            rl.drawRectangle(x + 2, item_y, MENU_WIDTH - 4, MENU_ITEM_HEIGHT, UI_ACTIVE);
        }

        const text_color = if (item.enabled) UI_TEXT else UI_TEXT_DIM;
        rl.drawText(item.label, x + 24, item_y + 4, 13, text_color);

        if (item.shortcut.len > 0) {
            const sw = rl.measureText(item.shortcut, 11);
            rl.drawText(item.shortcut, x + MENU_WIDTH - sw - 12, item_y + 5, 11, UI_TEXT_DIM);
        }

        item_y += MENU_ITEM_HEIGHT;
    }
}

fn isMouseInDropdown(app: *AppState) bool {
    const items = getMenuItems(app.open_menu);
    if (items.len == 0) return false;

    // Find the x position of the open menu
    var x: i32 = 8;
    for (menu_ids, 0..) |mid, i| {
        if (mid == app.open_menu) break;
        x += rl.measureText(menu_labels[i], 14) + 16;
    }

    var total_h: i32 = 8;
    for (items) |item| {
        total_h += if (item.is_separator) 7 else MENU_ITEM_HEIGHT;
    }

    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);

    return mx >= x and mx < x + MENU_WIDTH and my >= MENUBAR_HEIGHT and my < MENUBAR_HEIGHT + total_h;
}

fn handleMenuClick(app: *AppState) void {
    if (!rl.isMouseButtonPressed(.left)) return;

    const items = getMenuItems(app.open_menu);
    if (items.len == 0) return;

    // Find x position of open menu
    var x: i32 = 8;
    for (menu_ids, 0..) |mid, i| {
        if (mid == app.open_menu) break;
        x += rl.measureText(menu_labels[i], 14) + 16;
    }

    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);

    // Check which item was clicked
    var item_y: i32 = MENUBAR_HEIGHT + 4;
    for (items) |item| {
        if (item.is_separator) {
            item_y += 7;
            continue;
        }

        const hovered = mx >= x and mx < x + MENU_WIDTH and
            my >= item_y and my < item_y + MENU_ITEM_HEIGHT and item.enabled;

        if (hovered) {
            executeMenuItem(app, app.open_menu, item.label);
            app.open_menu = .none;
            return;
        }

        item_y += MENU_ITEM_HEIGHT;
    }
}

fn executeMenuItem(app: *AppState, menu: MenuId, label: [:0]const u8) void {
    switch (menu) {
        .file => {
            if (std.mem.eql(u8, label, "New")) {
                app.active_dialog = .new_image;
                app.clearDialogState();
            } else if (std.mem.eql(u8, label, "Open...")) {
                app.active_dialog = .file_open;
                app.clearDialogState();
            } else if (std.mem.eql(u8, label, "Save")) {
                app.saveFile();
            } else if (std.mem.eql(u8, label, "Save As...")) {
                app.active_dialog = .file_save_as;
                app.clearDialogState();
            } else if (std.mem.eql(u8, label, "Exit")) {
                rl.closeWindow();
            }
        },
        .view => {
            if (std.mem.eql(u8, label, "Zoom In")) {
                app.zoom_level = @min(app.zoom_level * 1.25, 32.0);
            } else if (std.mem.eql(u8, label, "Zoom Out")) {
                app.zoom_level = @max(app.zoom_level / 1.25, 0.1);
            } else if (std.mem.eql(u8, label, "Zoom to Fit")) {
                zoomToFit(app);
            } else if (std.mem.eql(u8, label, "Actual Size")) {
                app.zoom_level = 1.0;
                app.pan_x = 0;
                app.pan_y = 0;
            } else if (std.mem.eql(u8, label, "Toggle Grid")) {
                app.show_grid = !app.show_grid;
            }
        },
        .image => {
            if (std.mem.eql(u8, label, "Flatten")) {
                // Already single layer, no-op for now
            } else if (std.mem.eql(u8, label, "Flip Horizontal")) {
                flipHorizontal(app);
            } else if (std.mem.eql(u8, label, "Flip Vertical")) {
                flipVertical(app);
            }
        },
        .adjustments => {
            if (std.mem.eql(u8, label, "Invert Colors")) {
                invertColors(app);
            } else if (std.mem.eql(u8, label, "Grayscale")) {
                grayscaleImage(app);
            } else if (std.mem.eql(u8, label, "Sepia")) {
                sepiaImage(app);
            }
        },
        else => {},
    }
}

fn zoomToFit(app: *AppState) void {
    const screen_w = rl.getScreenWidth();
    const screen_h = rl.getScreenHeight();
    const area_w: f32 = @floatFromInt(screen_w - SIDEBAR_WIDTH - 40);
    const area_h: f32 = @floatFromInt(screen_h - CANVAS_Y - STATUSBAR_HEIGHT - 40);
    const scale_x = area_w / @as(f32, @floatFromInt(app.canvas_width));
    const scale_y = area_h / @as(f32, @floatFromInt(app.canvas_height));
    app.zoom_level = @min(scale_x, scale_y);
    app.pan_x = 0;
    app.pan_y = 0;
}

fn flipHorizontal(app: *AppState) void {
    if (app.canvas_pixels == null) return;
    const pixels = app.canvas_pixels.?;
    const w: usize = @intCast(app.canvas_width);
    const h: usize = @intCast(app.canvas_height);
    for (0..h) |y| {
        var left: usize = 0;
        var right: usize = w - 1;
        while (left < right) {
            const li = (y * w + left) * 4;
            const ri = (y * w + right) * 4;
            for (0..4) |c| {
                const tmp = pixels[li + c];
                pixels[li + c] = pixels[ri + c];
                pixels[ri + c] = tmp;
            }
            left += 1;
            right -= 1;
        }
    }
    app.canvas_dirty = true;
    app.has_unsaved_changes = true;
}

fn flipVertical(app: *AppState) void {
    if (app.canvas_pixels == null) return;
    const pixels = app.canvas_pixels.?;
    const w: usize = @intCast(app.canvas_width);
    const h: usize = @intCast(app.canvas_height);
    const row_bytes = w * 4;
    var top: usize = 0;
    var bottom: usize = h - 1;
    while (top < bottom) {
        for (0..row_bytes) |i| {
            const ti = top * row_bytes + i;
            const bi = bottom * row_bytes + i;
            const tmp = pixels[ti];
            pixels[ti] = pixels[bi];
            pixels[bi] = tmp;
        }
        top += 1;
        bottom -= 1;
    }
    app.canvas_dirty = true;
    app.has_unsaved_changes = true;
}

fn invertColors(app: *AppState) void {
    if (app.canvas_pixels == null) return;
    const pixels = app.canvas_pixels.?;
    const count: usize = @intCast(app.canvas_width * app.canvas_height);
    for (0..count) |i| {
        const idx = i * 4;
        pixels[idx] = 255 - pixels[idx];
        pixels[idx + 1] = 255 - pixels[idx + 1];
        pixels[idx + 2] = 255 - pixels[idx + 2];
        // Keep alpha unchanged
    }
    app.canvas_dirty = true;
    app.has_unsaved_changes = true;
}

fn grayscaleImage(app: *AppState) void {
    if (app.canvas_pixels == null) return;
    const pixels = app.canvas_pixels.?;
    const count: usize = @intCast(app.canvas_width * app.canvas_height);
    for (0..count) |i| {
        const idx = i * 4;
        const gray: u8 = @intFromFloat(
            @as(f32, @floatFromInt(pixels[idx])) * 0.299 +
                @as(f32, @floatFromInt(pixels[idx + 1])) * 0.587 +
                @as(f32, @floatFromInt(pixels[idx + 2])) * 0.114,
        );
        pixels[idx] = gray;
        pixels[idx + 1] = gray;
        pixels[idx + 2] = gray;
    }
    app.canvas_dirty = true;
    app.has_unsaved_changes = true;
}

fn sepiaImage(app: *AppState) void {
    if (app.canvas_pixels == null) return;
    const pixels = app.canvas_pixels.?;
    const count: usize = @intCast(app.canvas_width * app.canvas_height);
    for (0..count) |i| {
        const idx = i * 4;
        const rf: f32 = @floatFromInt(pixels[idx]);
        const gf: f32 = @floatFromInt(pixels[idx + 1]);
        const bf: f32 = @floatFromInt(pixels[idx + 2]);
        const nr: u8 = @intFromFloat(@min(rf * 0.393 + gf * 0.769 + bf * 0.189, 255.0));
        const ng: u8 = @intFromFloat(@min(rf * 0.349 + gf * 0.686 + bf * 0.168, 255.0));
        const nb: u8 = @intFromFloat(@min(rf * 0.272 + gf * 0.534 + bf * 0.131, 255.0));
        pixels[idx] = nr;
        pixels[idx + 1] = ng;
        pixels[idx + 2] = nb;
    }
    app.canvas_dirty = true;
    app.has_unsaved_changes = true;
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

fn handleDialogInput(app: *AppState) void {
    // Escape closes dialog
    if (rl.isKeyPressed(.escape)) {
        app.active_dialog = .none;
        return;
    }

    switch (app.active_dialog) {
        .file_open, .file_save_as => handleTextInput(&app.path_buf, &app.path_len, MAX_PATH_LEN),
        .new_image => {
            // Tab switches focus between width and height (handled by the dialog renderer)
            // For simplicity, we use a combined approach: type width first, then height
            // We'll use a simple heuristic based on cursor position
        },
        .none => {},
    }

    // Enter confirms dialog
    if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.kp_enter)) {
        switch (app.active_dialog) {
            .file_open => app.openFile(),
            .file_save_as => app.saveAsFile(),
            .new_image => app.newImage(),
            .none => {},
        }
    }
}

fn handleTextInput(buf: []u8, len: *usize, max_len: usize) void {
    // Handle character input
    var char = rl.getCharPressed();
    while (char != 0) {
        if (char >= 32 and char < 127 and len.* < max_len - 1) {
            buf[len.*] = @intCast(char);
            len.* += 1;
        }
        char = rl.getCharPressed();
    }

    // Backspace
    if (rl.isKeyPressed(.backspace) or rl.isKeyPressedRepeat(.backspace)) {
        if (len.* > 0) {
            len.* -= 1;
            buf[len.*] = 0;
        }
    }
}

const DIALOG_WIDTH = 450;
const DIALOG_HEIGHT_FILE = 160;
const DIALOG_HEIGHT_NEW = 200;
const INPUT_HEIGHT = 28;

fn drawDialog(app: *AppState, screen_w: i32, screen_h: i32) void {
    // Semi-transparent overlay
    rl.drawRectangle(0, 0, screen_w, screen_h, rl.Color.init(0, 0, 0, 120));

    switch (app.active_dialog) {
        .file_open => drawFileDialog(app, screen_w, screen_h, "Open File", "Open"),
        .file_save_as => drawFileDialog(app, screen_w, screen_h, "Save As", "Save"),
        .new_image => drawNewImageDialog(app, screen_w, screen_h),
        .none => {},
    }
}

fn drawFileDialog(app: *AppState, screen_w: i32, screen_h: i32, title: [:0]const u8, action_label: [:0]const u8) void {
    const dx = @divTrunc(screen_w - DIALOG_WIDTH, 2);
    const dy = @divTrunc(screen_h - DIALOG_HEIGHT_FILE, 2);

    // Dialog box
    rl.drawRectangle(dx, dy, DIALOG_WIDTH, DIALOG_HEIGHT_FILE, UI_DIALOG_BG);
    rl.drawRectangleLinesEx(.{
        .x = @floatFromInt(dx),
        .y = @floatFromInt(dy),
        .width = DIALOG_WIDTH,
        .height = DIALOG_HEIGHT_FILE,
    }, 2.0, UI_DIALOG_BORDER);

    // Title
    rl.drawText(title, dx + 16, dy + 12, 16, rl.Color.white);
    rl.drawLine(dx + 8, dy + 34, dx + DIALOG_WIDTH - 8, dy + 34, UI_BORDER);

    // File path label and input
    rl.drawText("File path:", dx + 16, dy + 44, 13, UI_TEXT);
    drawTextInput(dx + 16, dy + 62, DIALOG_WIDTH - 32, &app.path_buf, app.path_len);

    // Hint
    rl.drawText("Supported: .bmp", dx + 16, dy + 94, 11, UI_TEXT_DIM);

    // Status message
    if (app.dialog_status_len > 0) {
        const status_color = if (app.dialog_status_is_error) UI_ERROR_TEXT else UI_SUCCESS_TEXT;
        const status_slice = app.dialog_status[0..app.dialog_status_len];
        var status_z: [MAX_STATUS_LEN + 1]u8 = undefined;
        @memcpy(status_z[0..status_slice.len], status_slice);
        status_z[status_slice.len] = 0;
        rl.drawText(status_z[0..status_slice.len :0], dx + 16, dy + 108, 12, status_color);
    }

    // Buttons
    const btn_w: i32 = 80;
    const btn_h: i32 = 26;
    const btn_y = dy + DIALOG_HEIGHT_FILE - btn_h - 12;

    // Action button
    drawButton(dx + DIALOG_WIDTH - btn_w - 100, btn_y, btn_w, btn_h, action_label, true);

    // Cancel button
    drawButton(dx + DIALOG_WIDTH - btn_w - 12, btn_y, btn_w, btn_h, "Cancel", false);

    // Handle button clicks
    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);
    if (rl.isMouseButtonPressed(.left)) {
        // Action button
        if (mx >= dx + DIALOG_WIDTH - btn_w - 100 and mx < dx + DIALOG_WIDTH - 100 and
            my >= btn_y and my < btn_y + btn_h)
        {
            switch (app.active_dialog) {
                .file_open => app.openFile(),
                .file_save_as => app.saveAsFile(),
                else => {},
            }
        }
        // Cancel button
        if (mx >= dx + DIALOG_WIDTH - btn_w - 12 and mx < dx + DIALOG_WIDTH - 12 and
            my >= btn_y and my < btn_y + btn_h)
        {
            app.active_dialog = .none;
        }
    }
}

fn drawNewImageDialog(app: *AppState, screen_w: i32, screen_h: i32) void {
    const dx = @divTrunc(screen_w - DIALOG_WIDTH, 2);
    const dy = @divTrunc(screen_h - DIALOG_HEIGHT_NEW, 2);

    // Dialog box
    rl.drawRectangle(dx, dy, DIALOG_WIDTH, DIALOG_HEIGHT_NEW, UI_DIALOG_BG);
    rl.drawRectangleLinesEx(.{
        .x = @floatFromInt(dx),
        .y = @floatFromInt(dy),
        .width = DIALOG_WIDTH,
        .height = DIALOG_HEIGHT_NEW,
    }, 2.0, UI_DIALOG_BORDER);

    // Title
    rl.drawText("New Image", dx + 16, dy + 12, 16, rl.Color.white);
    rl.drawLine(dx + 8, dy + 34, dx + DIALOG_WIDTH - 8, dy + 34, UI_BORDER);

    // Width
    rl.drawText("Width:", dx + 16, dy + 48, 13, UI_TEXT);
    drawTextInput(dx + 80, dy + 44, 120, &app.new_width_buf, app.new_width_len);

    // Height
    rl.drawText("Height:", dx + 16, dy + 82, 13, UI_TEXT);
    drawTextInput(dx + 80, dy + 78, 120, &app.new_height_buf, app.new_height_len);

    // Handle text input for width/height fields
    // Use mouse click to determine which field gets input
    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);

    // Determine active field and route input
    const width_field_active = my >= dy + 44 and my < dy + 44 + INPUT_HEIGHT and mx >= dx + 80 and mx < dx + 200;
    const height_field_active = my >= dy + 78 and my < dy + 78 + INPUT_HEIGHT and mx >= dx + 80 and mx < dx + 200;

    // Default to width field for keyboard input, unless user clicked height field
    if (height_field_active and rl.isMouseButtonDown(.left)) {
        handleTextInput(&app.new_height_buf, &app.new_height_len, 8);
    } else {
        // Handle character input - try width first
        var char = rl.getCharPressed();
        while (char != 0) {
            if (char >= '0' and char <= '9') {
                if (app.new_width_len < 7) {
                    app.new_width_buf[app.new_width_len] = @intCast(char);
                    app.new_width_len += 1;
                }
            }
            char = rl.getCharPressed();
        }
        if (rl.isKeyPressed(.backspace) or rl.isKeyPressedRepeat(.backspace)) {
            if (app.new_width_len > 0) {
                app.new_width_len -= 1;
                app.new_width_buf[app.new_width_len] = 0;
            }
        }
    }

    // Hint
    rl.drawText("Max: 16384x16384", dx + 220, dy + 62, 11, UI_TEXT_DIM);

    // Status message
    if (app.dialog_status_len > 0) {
        const status_color = if (app.dialog_status_is_error) UI_ERROR_TEXT else UI_SUCCESS_TEXT;
        const status_slice = app.dialog_status[0..app.dialog_status_len];
        var status_z: [MAX_STATUS_LEN + 1]u8 = undefined;
        @memcpy(status_z[0..status_slice.len], status_slice);
        status_z[status_slice.len] = 0;
        rl.drawText(status_z[0..status_slice.len :0], dx + 16, dy + 118, 12, status_color);
    }

    // Buttons
    const btn_w: i32 = 80;
    const btn_h: i32 = 26;
    const btn_y = dy + DIALOG_HEIGHT_NEW - btn_h - 12;

    drawButton(dx + DIALOG_WIDTH - btn_w - 100, btn_y, btn_w, btn_h, "Create", true);
    drawButton(dx + DIALOG_WIDTH - btn_w - 12, btn_y, btn_w, btn_h, "Cancel", false);

    if (rl.isMouseButtonPressed(.left)) {
        if (mx >= dx + DIALOG_WIDTH - btn_w - 100 and mx < dx + DIALOG_WIDTH - 100 and
            my >= btn_y and my < btn_y + btn_h)
        {
            app.newImage();
        }
        if (mx >= dx + DIALOG_WIDTH - btn_w - 12 and mx < dx + DIALOG_WIDTH - 12 and
            my >= btn_y and my < btn_y + btn_h)
        {
            app.active_dialog = .none;
        }
    }

    _ = width_field_active;
}

fn drawTextInput(x: i32, y: i32, w: i32, buf: []const u8, len: usize) void {
    rl.drawRectangle(x, y, w, INPUT_HEIGHT, UI_INPUT_BG);
    rl.drawRectangleLinesEx(.{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = @floatFromInt(w),
        .height = INPUT_HEIGHT,
    }, 1.0, UI_BORDER);

    if (len > 0) {
        // Create null-terminated slice for display
        var display_buf: [MAX_PATH_LEN + 1]u8 = undefined;
        const display_len = @min(len, MAX_PATH_LEN);
        @memcpy(display_buf[0..display_len], buf[0..display_len]);
        display_buf[display_len] = 0;
        rl.drawText(display_buf[0..display_len :0], x + 6, y + 7, 13, UI_TEXT);
    }

    // Blinking cursor
    const time: i32 = @intFromFloat(rl.getTime() * 2.0);
    if (@mod(time, 2) == 0) {
        const cursor_x = x + 6 + if (len > 0) blk: {
            var measure_buf: [MAX_PATH_LEN + 1]u8 = undefined;
            const measure_len = @min(len, MAX_PATH_LEN);
            @memcpy(measure_buf[0..measure_len], buf[0..measure_len]);
            measure_buf[measure_len] = 0;
            break :blk rl.measureText(measure_buf[0..measure_len :0], 13);
        } else @as(i32, 0);
        rl.drawLine(cursor_x, y + 5, cursor_x, y + INPUT_HEIGHT - 5, UI_TEXT);
    }
}

fn drawButton(x: i32, y: i32, w: i32, h: i32, label: [:0]const u8, primary: bool) void {
    const mouse = rl.getMousePosition();
    const mx: i32 = @intFromFloat(mouse.x);
    const my: i32 = @intFromFloat(mouse.y);
    const hovered = mx >= x and mx < x + w and my >= y and my < y + h;

    const bg = if (primary)
        (if (hovered) rl.Color.init(0, 140, 230, 255) else UI_ACTIVE)
    else
        (if (hovered) UI_HOVER else UI_PANEL);

    rl.drawRectangle(x, y, w, h, bg);
    rl.drawRectangleLinesEx(.{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = @floatFromInt(w),
        .height = @floatFromInt(h),
    }, 1.0, if (primary) UI_ACTIVE else UI_BORDER);

    const tw = rl.measureText(label, 13);
    rl.drawText(label, x + @divTrunc(w - tw, 2), y + 6, 13, rl.Color.white);
}

fn endsWithIgnoreCase(str: []const u8, suffix: []const u8) bool {
    if (str.len < suffix.len) return false;
    const tail = str[str.len - suffix.len ..];
    for (tail, suffix) |a, b| {
        const la = if (a >= 'A' and a <= 'Z') a + 32 else a;
        const lb = if (b >= 'A' and b <= 'Z') b + 32 else b;
        if (la != lb) return false;
    }
    return true;
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
