const std = @import("std");
const testing = std.testing;
const Color = @import("../core/color.zig").Color;
const Image = @import("../core/image.zig").Image;

/// BMP file format reader/writer
pub const Bmp = struct {
    /// Write an image as BMP to a writer
    pub fn write(image: *const Image, writer: anytype) !void {
        const w = image.width;
        const h = image.height;
        const row_size = w * 4;
        const padding = (4 - (row_size % 4)) % 4;
        const padded_row = row_size + padding;
        const pixel_data_size: u32 = padded_row * h;
        const file_size: u32 = 54 + pixel_data_size;

        // BMP File Header (14 bytes)
        try writer.writeAll("BM");
        try writer.writeInt(u32, file_size, .little);
        try writer.writeInt(u16, 0, .little); // reserved
        try writer.writeInt(u16, 0, .little); // reserved
        try writer.writeInt(u32, 54, .little); // pixel data offset

        // DIB Header (BITMAPINFOHEADER, 40 bytes)
        try writer.writeInt(u32, 40, .little); // header size
        try writer.writeInt(i32, @intCast(w), .little);
        try writer.writeInt(i32, @intCast(h), .little); // positive = bottom-up
        try writer.writeInt(u16, 1, .little); // planes
        try writer.writeInt(u16, 32, .little); // bits per pixel
        try writer.writeInt(u32, 0, .little); // compression (none)
        try writer.writeInt(u32, pixel_data_size, .little);
        try writer.writeInt(i32, 2835, .little); // x pixels per meter
        try writer.writeInt(i32, 2835, .little); // y pixels per meter
        try writer.writeInt(u32, 0, .little); // colors used
        try writer.writeInt(u32, 0, .little); // important colors

        // Pixel data (bottom-up, BGRA order)
        const pad_bytes = [_]u8{0} ** 4;
        var y: u32 = h;
        while (y > 0) {
            y -= 1;
            var x: u32 = 0;
            while (x < w) : (x += 1) {
                const pixel = image.getPixel(x, y) orelse Color.transparent;
                try writer.writeByte(pixel.b);
                try writer.writeByte(pixel.g);
                try writer.writeByte(pixel.r);
                try writer.writeByte(pixel.a);
            }
            if (padding > 0) {
                try writer.writeAll(pad_bytes[0..padding]);
            }
        }
    }

    /// Read a BMP image from a reader
    pub fn read(allocator: std.mem.Allocator, reader: anytype) !Image {
        // BMP File Header
        var magic: [2]u8 = undefined;
        _ = try reader.readAll(&magic);
        if (!std.mem.eql(u8, &magic, "BM")) return error.InvalidBmpFormat;

        _ = try reader.readInt(u32, .little); // file size
        _ = try reader.readInt(u16, .little); // reserved
        _ = try reader.readInt(u16, .little); // reserved
        const data_offset = try reader.readInt(u32, .little);

        // DIB Header
        const header_size = try reader.readInt(u32, .little);
        if (header_size < 40) return error.UnsupportedBmpHeader;

        const width_i32 = try reader.readInt(i32, .little);
        const height_i32 = try reader.readInt(i32, .little);
        const bottom_up = height_i32 > 0;

        const width: u32 = @intCast(@abs(width_i32));
        const height: u32 = @intCast(@abs(height_i32));

        _ = try reader.readInt(u16, .little); // planes
        const bpp = try reader.readInt(u16, .little);
        if (bpp != 24 and bpp != 32) return error.UnsupportedBppFormat;

        // Skip rest of header + any gap to pixel data
        const bytes_read: u32 = 14 + 4 + 12; // file header + header_size field + w/h/planes/bpp
        const remaining = data_offset - bytes_read;
        try reader.skipBytes(remaining, .{});

        var img = try Image.init(allocator, width, height);
        errdefer img.deinit();

        const row_bytes = width * (bpp / 8);
        const padding = (4 - (row_bytes % 4)) % 4;

        var y: u32 = 0;
        while (y < height) : (y += 1) {
            const actual_y = if (bottom_up) height - 1 - y else y;
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const b = try reader.readByte();
                const g = try reader.readByte();
                const r = try reader.readByte();
                const a: u8 = if (bpp == 32) try reader.readByte() else 255;
                img.setPixel(x, actual_y, Color.init(r, g, b, a));
            }
            try reader.skipBytes(padding, .{});
        }

        return img;
    }

    /// Write BMP to a file
    pub fn writeFile(image: *const Image, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try write(image, file.writer());
    }

    /// Read BMP from a file
    pub fn readFile(allocator: std.mem.Allocator, path: []const u8) !Image {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        return read(allocator, file.reader());
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BMP write and read roundtrip" {
    var img = try Image.initWithColor(testing.allocator, 4, 4, Color.red);
    defer img.deinit();

    img.setPixel(0, 0, Color.blue);
    img.setPixel(3, 3, Color.green);

    // Write to buffer
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(testing.allocator);
    try Bmp.write(&img, buf.writer(testing.allocator));

    // Read back
    var stream = std.io.fixedBufferStream(buf.items);
    var read_img = try Bmp.read(testing.allocator, stream.reader());
    defer read_img.deinit();

    try testing.expectEqual(img.width, read_img.width);
    try testing.expectEqual(img.height, read_img.height);
    try testing.expect(read_img.getPixel(0, 0).?.eql(Color.blue));
    try testing.expect(read_img.getPixel(1, 1).?.eql(Color.red));
    try testing.expect(read_img.getPixel(3, 3).?.eql(Color.green));
}

test "BMP write generates valid header" {
    var img = try Image.init(testing.allocator, 2, 2);
    defer img.deinit();

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(testing.allocator);
    try Bmp.write(&img, buf.writer(testing.allocator));

    // Check BMP magic
    try testing.expectEqualStrings("BM", buf.items[0..2]);

    // Check pixel data offset
    var stream = std.io.fixedBufferStream(buf.items);
    var reader = stream.reader();
    try reader.skipBytes(10, .{});
    const offset = try reader.readInt(u32, .little);
    try testing.expectEqual(@as(u32, 54), offset);
}

test "BMP read invalid magic fails" {
    const data = "XX" ++ "\x00" ** 52;
    var stream = std.io.fixedBufferStream(data);
    const result = Bmp.read(testing.allocator, stream.reader());
    try testing.expectError(error.InvalidBmpFormat, result);
}

test "BMP various sizes" {
    const sizes = [_]u32{ 1, 3, 7, 16, 100 };
    for (sizes) |size| {
        var img = try Image.initWithColor(testing.allocator, size, size, Color.init(42, 84, 126, 255));
        defer img.deinit();

        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(testing.allocator);
        try Bmp.write(&img, buf.writer(testing.allocator));

        var stream = std.io.fixedBufferStream(buf.items);
        var read_img = try Bmp.read(testing.allocator, stream.reader());
        defer read_img.deinit();

        try testing.expectEqual(size, read_img.width);
        try testing.expectEqual(size, read_img.height);
        const pixel = read_img.getPixel(0, 0).?;
        try testing.expectEqual(@as(u8, 42), pixel.r);
        try testing.expectEqual(@as(u8, 84), pixel.g);
        try testing.expectEqual(@as(u8, 126), pixel.b);
    }
}
