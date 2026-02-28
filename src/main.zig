//! Main entry point for Paint.Zig.
//! Implements the application loop using SDL2 for windowing and input.

const std = @import("std");
const app_mod = @import("app.zig");
const canvas_mod = @import("canvas.zig");
const color_mod = @import("color.zig");
const pencil_tool = @import("tools/pencil.zig");
const brush_tool = @import("tools/brush.zig");
const eraser_tool = @import("tools/eraser.zig");
const fill_tool = @import("tools/fill.zig");
const shapes_tool = @import("tools/shapes.zig");
const renderer_mod = @import("ui/renderer.zig");

const AppState = app_mod.AppState;
const ToolKind = app_mod.ToolKind;
const Rgba = color_mod.Rgba;
const sdl = renderer_mod.sdl;
const Renderer = renderer_mod.Renderer;

const WINDOW_W: u32 = 1280;
const WINDOW_H: u32 = 800;
const CANVAS_W: u32 = 800;
const CANVAS_H: u32 = 600;
const TOOLBAR_W: i32 = 48;
const PALETTE_H: i32 = 48;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = try AppState.init(allocator, CANVAS_W, CANVAS_H);
    defer state.deinit();

    // Start with a white background
    state.fillBackground();

    var renderer = try Renderer.init(
        "Paint.Zig",
        WINDOW_W,
        WINDOW_H,
        CANVAS_W,
        CANVAS_H,
    );
    defer renderer.deinit();

    // Allocate pixel buffer for texture upload
    const pixel_buf = try allocator.alloc(u32, CANVAS_W * CANVAS_H);
    defer allocator.free(pixel_buf);

    var shape_start_x: i32 = 0;
    var shape_start_y: i32 = 0;

    var running = true;
    while (running) {
        // ── Event handling ────────────────────────────────────────────────────
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => running = false,

                sdl.SDL_KEYDOWN => {
                    const sym = event.key.keysym.sym;
                    const ctrl = (event.key.keysym.mod & sdl.KMOD_CTRL) != 0;

                    if (ctrl) {
                        switch (sym) {
                            sdl.SDLK_z => _ = state.undo(),
                            sdl.SDLK_y => _ = state.redo(),
                            sdl.SDLK_EQUALS, sdl.SDLK_PLUS => state.zoomIn(),
                            sdl.SDLK_MINUS => state.zoomOut(),
                            sdl.SDLK_0 => state.zoomReset(),
                            else => {},
                        }
                    } else {
                        switch (sym) {
                            sdl.SDLK_p => state.active_tool = .pencil,
                            sdl.SDLK_b => state.active_tool = .brush,
                            sdl.SDLK_e => state.active_tool = .eraser,
                            sdl.SDLK_f => state.active_tool = .fill,
                            sdl.SDLK_l => state.active_tool = .line,
                            sdl.SDLK_r => state.active_tool = .rectangle,
                            sdl.SDLK_o => state.active_tool = .ellipse,
                            else => {},
                        }
                    }
                },

                sdl.SDL_MOUSEWHEEL => {
                    if (event.wheel.y > 0) state.zoomIn() else state.zoomOut();
                },

                sdl.SDL_MOUSEBUTTONDOWN => {
                    if (event.button.button == sdl.SDL_BUTTON_LEFT) {
                        const pos = state.screenToCanvas(
                            @floatFromInt(event.button.x - TOOLBAR_W),
                            @floatFromInt(event.button.y),
                        );
                        const cx: i32 = @intFromFloat(pos[0]);
                        const cy: i32 = @intFromFloat(pos[1]);

                        shape_start_x = cx;
                        shape_start_y = cy;

                        try state.beginStroke(pos[0], pos[1]);

                        switch (state.active_tool) {
                            .pencil => pencil_tool.drawPoint(&state.canvas, cx, cy, .{
                                .foreground = state.foreground_color,
                                .size = @intFromFloat(state.brush_size),
                            }),
                            .eraser => eraser_tool.erase(&state.canvas, pos[0], pos[1], .{
                                .radius = state.brush_size,
                                .opacity = state.brush_opacity,
                            }),
                            .fill => try fill_tool.floodFill(&state.canvas, @max(0, cx), @max(0, cy), .{
                                .fill_color = state.foreground_color,
                                .tolerance = state.tolerance,
                            }, allocator),
                            .brush => brush_tool.drawDab(&state.canvas, pos[0], pos[1], .{
                                .foreground = state.foreground_color,
                                .radius = state.brush_size,
                                .opacity = state.brush_opacity,
                                .soft = true,
                            }),
                            else => {},
                        }
                    }
                },

                sdl.SDL_MOUSEMOTION => {
                    if (state.is_drawing) {
                        const pos = state.screenToCanvas(
                            @floatFromInt(event.motion.x - TOOLBAR_W),
                            @floatFromInt(event.motion.y),
                        );
                        switch (state.active_tool) {
                            .pencil => pencil_tool.drawLine(
                                &state.canvas,
                                @intFromFloat(state.last_x),
                                @intFromFloat(state.last_y),
                                @intFromFloat(pos[0]),
                                @intFromFloat(pos[1]),
                                .{
                                    .foreground = state.foreground_color,
                                    .size = @intFromFloat(state.brush_size),
                                },
                            ),
                            .brush => brush_tool.drawStroke(
                                &state.canvas,
                                state.last_x,
                                state.last_y,
                                pos[0],
                                pos[1],
                                .{
                                    .foreground = state.foreground_color,
                                    .radius = state.brush_size,
                                    .opacity = state.brush_opacity,
                                    .soft = true,
                                },
                            ),
                            .eraser => eraser_tool.eraseLine(
                                &state.canvas,
                                state.last_x,
                                state.last_y,
                                pos[0],
                                pos[1],
                                .{
                                    .radius = state.brush_size,
                                    .opacity = state.brush_opacity,
                                },
                            ),
                            else => {},
                        }
                        state.last_x = pos[0];
                        state.last_y = pos[1];
                    }
                },

                sdl.SDL_MOUSEBUTTONUP => {
                    if (event.button.button == sdl.SDL_BUTTON_LEFT and state.is_drawing) {
                        const pos = state.screenToCanvas(
                            @floatFromInt(event.button.x - TOOLBAR_W),
                            @floatFromInt(event.button.y),
                        );
                        const cx: i32 = @intFromFloat(pos[0]);
                        const cy: i32 = @intFromFloat(pos[1]);

                        switch (state.active_tool) {
                            .line => shapes_tool.drawLine(
                                &state.canvas,
                                shape_start_x,
                                shape_start_y,
                                cx,
                                cy,
                                .{ .stroke_color = state.foreground_color, .stroke_width = 1 },
                            ),
                            .rectangle => shapes_tool.drawRect(
                                &state.canvas,
                                shape_start_x,
                                shape_start_y,
                                cx,
                                cy,
                                .{ .stroke_color = state.foreground_color, .stroke_width = 1 },
                            ),
                            .ellipse => shapes_tool.drawEllipse(
                                &state.canvas,
                                shape_start_x,
                                shape_start_y,
                                cx,
                                cy,
                                .{ .stroke_color = state.foreground_color, .stroke_width = 1 },
                            ),
                            else => {},
                        }
                        try state.endStroke();
                    }
                },

                else => {},
            }
        }

        // ── Rendering ─────────────────────────────────────────────────────────
        const win_size = renderer.getWindowSize();
        renderer.clear(40, 40, 40);

        // Flatten canvas layers to ARGB pixel buffer
        const flat = try state.canvas.flatten(allocator);
        defer allocator.free(flat);
        for (flat, 0..) |px, i| {
            pixel_buf[i] = px.toArgb();
        }
        renderer.uploadPixels(pixel_buf);

        // Draw canvas at current pan/zoom
        const cw: i32 = @intFromFloat(@as(f32, CANVAS_W) * state.zoom);
        const ch: i32 = @intFromFloat(@as(f32, CANVAS_H) * state.zoom);
        renderer.drawCanvas(TOOLBAR_W + @as(i32, @intFromFloat(state.pan_x)), @as(i32, @intFromFloat(state.pan_y)), cw, ch);

        // Draw toolbar background
        renderer.fillRect(0, 0, TOOLBAR_W, win_size[1], 50, 50, 60, 255);

        // Draw tool buttons (simple colored squares)
        const tools_list = [_]struct { kind: ToolKind, r: u8, g: u8, b: u8 }{
            .{ .kind = .pencil, .r = 200, .g = 200, .b = 200 },
            .{ .kind = .brush, .r = 100, .g = 180, .b = 255 },
            .{ .kind = .eraser, .r = 255, .g = 200, .b = 200 },
            .{ .kind = .fill, .r = 255, .g = 220, .b = 100 },
            .{ .kind = .line, .r = 180, .g = 255, .b = 180 },
            .{ .kind = .rectangle, .r = 255, .g = 180, .b = 100 },
            .{ .kind = .ellipse, .r = 200, .g = 100, .b = 255 },
        };
        for (tools_list, 0..) |tool, idx| {
            const ty: i32 = 8 + @as(i32, @intCast(idx)) * 50;
            const is_active = state.active_tool == tool.kind;
            renderer.fillRect(4, ty, 40, 40, tool.r, tool.g, tool.b, if (is_active) 255 else 140);
            if (is_active) {
                renderer.drawRect(3, ty - 1, 42, 42, 255, 255, 255);
            }
        }

        // Draw color swatches
        const swatch_y: i32 = win_size[1] - PALETTE_H;
        renderer.fillRect(0, swatch_y, win_size[0], PALETTE_H, 45, 45, 55, 255);
        renderer.fillRect(8, swatch_y + 8, 28, 28, state.foreground_color.r, state.foreground_color.g, state.foreground_color.b, 255);
        renderer.fillRect(16, swatch_y + 16, 28, 28, state.background_color.r, state.background_color.g, state.background_color.b, 255);

        renderer.present();
    }
}
