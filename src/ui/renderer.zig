//! SDL2-based renderer for Paint.Zig.
//! Handles window management, event dispatch, and immediate-mode rendering.

const std = @import("std");

// C SDL2 bindings
pub const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const RendererError = error{
    InitFailed,
    WindowCreationFailed,
    RendererCreationFailed,
    TextureCreationFailed,
};

pub const Renderer = struct {
    window: *sdl.SDL_Window,
    sdl_renderer: *sdl.SDL_Renderer,
    canvas_texture: *sdl.SDL_Texture,
    canvas_width: u32,
    canvas_height: u32,

    pub fn init(
        title: [*c]const u8,
        window_width: u32,
        window_height: u32,
        canvas_width: u32,
        canvas_height: u32,
    ) !Renderer {
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
            return RendererError.InitFailed;
        }

        const window = sdl.SDL_CreateWindow(
            title,
            sdl.SDL_WINDOWPOS_CENTERED,
            sdl.SDL_WINDOWPOS_CENTERED,
            @intCast(window_width),
            @intCast(window_height),
            sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
        ) orelse return RendererError.WindowCreationFailed;

        const renderer = sdl.SDL_CreateRenderer(
            window,
            -1,
            sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC,
        ) orelse {
            sdl.SDL_DestroyWindow(window);
            return RendererError.RendererCreationFailed;
        };

        // Canvas texture in ARGB8888 format for fast pixel upload
        const texture = sdl.SDL_CreateTexture(
            renderer,
            sdl.SDL_PIXELFORMAT_ARGB8888,
            sdl.SDL_TEXTUREACCESS_STREAMING,
            @intCast(canvas_width),
            @intCast(canvas_height),
        ) orelse {
            sdl.SDL_DestroyRenderer(renderer);
            sdl.SDL_DestroyWindow(window);
            return RendererError.TextureCreationFailed;
        };

        _ = sdl.SDL_SetTextureBlendMode(texture, sdl.SDL_BLENDMODE_BLEND);

        return .{
            .window = window,
            .sdl_renderer = renderer,
            .canvas_texture = texture,
            .canvas_width = canvas_width,
            .canvas_height = canvas_height,
        };
    }

    pub fn deinit(self: *Renderer) void {
        sdl.SDL_DestroyTexture(self.canvas_texture);
        sdl.SDL_DestroyRenderer(self.sdl_renderer);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    /// Upload flattened ARGB pixel data to the canvas texture.
    pub fn uploadPixels(self: *Renderer, argb_pixels: []const u32) void {
        var ptr: ?*anyopaque = null;
        var pitch: c_int = 0;
        if (sdl.SDL_LockTexture(self.canvas_texture, null, &ptr, &pitch) == 0) {
            const dst: [*]u32 = @ptrCast(@alignCast(ptr));
            const row_pixels: usize = @intCast(@divTrunc(pitch, 4));
            for (0..self.canvas_height) |y| {
                for (0..self.canvas_width) |x| {
                    dst[y * row_pixels + x] = argb_pixels[y * self.canvas_width + x];
                }
            }
            sdl.SDL_UnlockTexture(self.canvas_texture);
        }
    }

    /// Clear the screen to a background color.
    pub fn clear(self: *Renderer, r: u8, g: u8, b: u8) void {
        _ = sdl.SDL_SetRenderDrawColor(self.sdl_renderer, r, g, b, 255);
        _ = sdl.SDL_RenderClear(self.sdl_renderer);
    }

    /// Draw the canvas texture at the given viewport position and scale.
    pub fn drawCanvas(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        const dst = sdl.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = sdl.SDL_RenderCopy(self.sdl_renderer, self.canvas_texture, null, &dst);
    }

    /// Draw a filled rectangle (for UI elements).
    pub fn fillRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, r: u8, g: u8, b: u8, a: u8) void {
        _ = sdl.SDL_SetRenderDrawColor(self.sdl_renderer, r, g, b, a);
        _ = sdl.SDL_SetRenderDrawBlendMode(self.sdl_renderer, sdl.SDL_BLENDMODE_BLEND);
        const rect = sdl.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = sdl.SDL_RenderFillRect(self.sdl_renderer, &rect);
    }

    /// Draw a rectangle outline.
    pub fn drawRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, r: u8, g: u8, b: u8) void {
        _ = sdl.SDL_SetRenderDrawColor(self.sdl_renderer, r, g, b, 255);
        const rect = sdl.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = sdl.SDL_RenderDrawRect(self.sdl_renderer, &rect);
    }

    /// Present the rendered frame.
    pub fn present(self: *Renderer) void {
        sdl.SDL_RenderPresent(self.sdl_renderer);
    }

    /// Get the current window size.
    pub fn getWindowSize(self: *Renderer) [2]i32 {
        var w: c_int = 0;
        var h: c_int = 0;
        sdl.SDL_GetWindowSize(self.window, &w, &h);
        return .{ @intCast(w), @intCast(h) };
    }
};
