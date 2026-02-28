//! BMP image format reader and writer (pure Zig, no external dependencies).
//! Supports 24-bit (BGR) and 32-bit (BGRA) uncompressed BMP files.

const std = @import("std");
const color = @import("color.zig");
const Rgba = color.Rgba;

pub const ImageError = error{
    InvalidHeader,
    UnsupportedFormat,
    InvalidDimensions,
    OutOfMemory,
    EndOfStream,
    UnexpectedEof,
};

pub const Image = struct {
    pixels: []Rgba,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        if (width == 0 or height == 0) return ImageError.InvalidDimensions;
        const pixels = try allocator.alloc(Rgba, width * height);
        for (pixels) |*p| p.* = Rgba.transparent;
        return .{
            .pixels = pixels,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.pixels);
    }

    pub fn getPixel(self: *const Image, x: u32, y: u32) ?Rgba {
        if (x >= self.width or y >= self.height) return null;
        return self.pixels[y * self.width + x];
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, c: Rgba) void {
        if (x >= self.width or y >= self.height) return;
        self.pixels[y * self.width + x] = c;
    }
};

/// BMP file header constants
const BMP_SIGNATURE: u16 = 0x4D42; // 'BM'
const DIB_BITMAPINFOHEADER_SIZE: u32 = 40;

/// Write a 24-bit BMP file to a writer.
pub fn writeBmp(image: *const Image, writer: anytype) !void {
    const row_bytes_unpadded = image.width * 3;
    const row_padding = (4 - (row_bytes_unpadded % 4)) % 4;
    const row_stride = row_bytes_unpadded + row_padding;
    const pixel_data_size = row_stride * image.height;
    const file_size: u32 = 14 + DIB_BITMAPINFOHEADER_SIZE + pixel_data_size;
    const pixel_offset: u32 = 14 + DIB_BITMAPINFOHEADER_SIZE;

    // File header (14 bytes)
    try writer.writeInt(u16, BMP_SIGNATURE, .little);
    try writer.writeInt(u32, file_size, .little);
    try writer.writeInt(u16, 0, .little); // reserved1
    try writer.writeInt(u16, 0, .little); // reserved2
    try writer.writeInt(u32, pixel_offset, .little);

    // DIB header (BITMAPINFOHEADER, 40 bytes)
    try writer.writeInt(u32, DIB_BITMAPINFOHEADER_SIZE, .little);
    try writer.writeInt(i32, @intCast(image.width), .little);
    // Negative height = top-down row order
    try writer.writeInt(i32, -@as(i32, @intCast(image.height)), .little);
    try writer.writeInt(u16, 1, .little); // color planes
    try writer.writeInt(u16, 24, .little); // bits per pixel
    try writer.writeInt(u32, 0, .little); // BI_RGB (no compression)
    try writer.writeInt(u32, pixel_data_size, .little);
    try writer.writeInt(i32, 2835, .little); // X pixels per meter (~72 DPI)
    try writer.writeInt(i32, 2835, .little); // Y pixels per meter
    try writer.writeInt(u32, 0, .little); // colors in table
    try writer.writeInt(u32, 0, .little); // important colors

    // Pixel data (BGR, rows bottom-to-top unless negative height used above)
    for (0..image.height) |row| {
        for (0..image.width) |col| {
            const p = image.pixels[row * image.width + col];
            try writer.writeByte(p.b);
            try writer.writeByte(p.g);
            try writer.writeByte(p.r);
        }
        // Row padding
        for (0..row_padding) |_| {
            try writer.writeByte(0);
        }
    }
}

/// Read a BMP file from a reader. Returns an Image the caller must free.
pub fn readBmp(allocator: std.mem.Allocator, reader: anytype) !Image {
    // File header (14 bytes total)
    const sig = try reader.readInt(u16, .little);
    if (sig != BMP_SIGNATURE) return ImageError.InvalidHeader;

    _ = try reader.readInt(u32, .little); // file_size
    _ = try reader.readInt(u16, .little); // reserved1
    _ = try reader.readInt(u16, .little); // reserved2
    const pixel_offset = try reader.readInt(u32, .little);

    // DIB header — read dib_size first, then the standard fields
    const dib_size = try reader.readInt(u32, .little);
    if (dib_size < DIB_BITMAPINFOHEADER_SIZE) return ImageError.UnsupportedFormat;

    const width = try reader.readInt(i32, .little);
    const height_raw = try reader.readInt(i32, .little);
    _ = try reader.readInt(u16, .little); // color planes
    const bpp = try reader.readInt(u16, .little);
    const compression = try reader.readInt(u32, .little);

    if (compression != 0) return ImageError.UnsupportedFormat;
    if (bpp != 24 and bpp != 32) return ImageError.UnsupportedFormat;
    if (width <= 0) return ImageError.InvalidDimensions;

    const uwidth: u32 = @intCast(width);
    const top_down = height_raw < 0;
    const uheight: u32 = if (top_down) @intCast(-height_raw) else @intCast(height_raw);
    if (uheight == 0) return ImageError.InvalidDimensions;

    // We have read: 14 (file header) + 4 (dib_size) + 16 (above fields) = 34 bytes.
    // Skip the rest of the DIB header, then any gap before pixel data.
    // Total bytes read so far from start of file: 34
    const bytes_read_so_far: u32 = 34;
    // Full DIB header ends at: 14 + dib_size
    const dib_end: u32 = 14 + dib_size;
    // Skip remaining DIB header bytes (if dib_size > 20, i.e. bytes_read > 34)
    if (dib_end > bytes_read_so_far) {
        var skip = dib_end - bytes_read_so_far;
        while (skip > 0) : (skip -= 1) {
            _ = try reader.readByte();
        }
    }
    // Skip any gap between end of DIB header and pixel data
    if (pixel_offset > dib_end) {
        var skip = pixel_offset - dib_end;
        while (skip > 0) : (skip -= 1) {
            _ = try reader.readByte();
        }
    }

    var image = try Image.init(allocator, uwidth, uheight);
    errdefer image.deinit();

    const bytes_per_pixel: u32 = bpp / 8;
    const row_bytes_unpadded = uwidth * bytes_per_pixel;
    const row_padding = (4 - (row_bytes_unpadded % 4)) % 4;

    for (0..uheight) |row_idx| {
        const row: u32 = if (top_down)
            @intCast(row_idx)
        else
            uheight - 1 - @as(u32, @intCast(row_idx));

        for (0..uwidth) |col| {
            const b = try reader.readByte();
            const g = try reader.readByte();
            const r = try reader.readByte();
            const a: u8 = if (bpp == 32) try reader.readByte() else 255;
            image.pixels[row * uwidth + col] = .{ .r = r, .g = g, .b = b, .a = a };
        }
        for (0..row_padding) |_| {
            _ = try reader.readByte();
        }
    }

    return image;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test "Image.init and deinit" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 10, 10);
    defer img.deinit();

    try std.testing.expectEqual(@as(u32, 10), img.width);
    try std.testing.expectEqual(@as(u32, 10), img.height);
}

test "Image.init zero dimensions fails" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(ImageError.InvalidDimensions, Image.init(allocator, 0, 10));
    try std.testing.expectError(ImageError.InvalidDimensions, Image.init(allocator, 10, 0));
}

test "Image.setPixel and getPixel" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 8, 8);
    defer img.deinit();

    img.setPixel(3, 4, Rgba.green);
    try std.testing.expectEqual(Rgba.green, img.getPixel(3, 4).?);
    try std.testing.expectEqual(null, img.getPixel(100, 100));
}

test "BMP write/read round-trip 1x1" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 1, 1);
    defer img.deinit();

    img.setPixel(0, 0, Rgba{ .r = 200, .g = 100, .b = 50, .a = 255 });

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try writeBmp(&img, buf.writer());

    var fbs = std.io.fixedBufferStream(buf.items);
    var loaded = try readBmp(allocator, fbs.reader());
    defer loaded.deinit();

    try std.testing.expectEqual(@as(u32, 1), loaded.width);
    try std.testing.expectEqual(@as(u32, 1), loaded.height);
    const p = loaded.getPixel(0, 0).?;
    try std.testing.expectEqual(@as(u8, 200), p.r);
    try std.testing.expectEqual(@as(u8, 100), p.g);
    try std.testing.expectEqual(@as(u8, 50), p.b);
}

test "BMP write/read round-trip 4x4 checkerboard" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 4, 4);
    defer img.deinit();

    for (0..4) |y| {
        for (0..4) |x| {
            const c = if ((x + y) % 2 == 0) Rgba.white else Rgba.black;
            img.setPixel(@intCast(x), @intCast(y), c);
        }
    }

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();
    try writeBmp(&img, buf.writer());

    var fbs = std.io.fixedBufferStream(buf.items);
    var loaded = try readBmp(allocator, fbs.reader());
    defer loaded.deinit();

    for (0..4) |y| {
        for (0..4) |x| {
            const expected = if ((x + y) % 2 == 0) Rgba.white else Rgba.black;
            const actual = loaded.getPixel(@intCast(x), @intCast(y)).?;
            try std.testing.expectEqual(expected.r, actual.r);
            try std.testing.expectEqual(expected.g, actual.g);
            try std.testing.expectEqual(expected.b, actual.b);
        }
    }
}

test "BMP invalid signature" {
    const allocator = std.testing.allocator;
    const bad_data = [_]u8{ 0x00, 0x00 };
    var fbs = std.io.fixedBufferStream(&bad_data);
    try std.testing.expectError(ImageError.InvalidHeader, readBmp(allocator, fbs.reader()));
}
