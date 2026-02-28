const std = @import("std");
const img = @import("image.zig");
const Color = img.Color;
const Image = img.Image;

/// Write an Image to a BMP file (32-bit BGRA, top-down DIB).
pub fn writeBmp(image: *const Image, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try writeBmpToWriter(image, file.writer());
}

/// Write BMP data to any writer.
pub fn writeBmpToWriter(image: *const Image, writer: anytype) !void {
    const w: u32 = image.width;
    const h: u32 = image.height;
    const row_bytes: u32 = w * 4;
    const pixel_data_size: u32 = row_bytes * h;
    const file_size: u32 = 14 + 108 + pixel_data_size; // BITMAPV4HEADER

    // BMP file header (14 bytes)
    try writer.writeAll("BM");
    try writer.writeInt(u32, file_size, .little);
    try writer.writeInt(u16, 0, .little); // reserved
    try writer.writeInt(u16, 0, .little); // reserved
    try writer.writeInt(u32, 14 + 108, .little); // pixel data offset

    // BITMAPV4HEADER (108 bytes)
    try writer.writeInt(u32, 108, .little); // header size
    try writer.writeInt(i32, @intCast(w), .little); // width
    try writer.writeInt(i32, -@as(i32, @intCast(h)), .little); // height (negative = top-down)
    try writer.writeInt(u16, 1, .little); // planes
    try writer.writeInt(u16, 32, .little); // bits per pixel
    try writer.writeInt(u32, 3, .little); // compression = BI_BITFIELDS
    try writer.writeInt(u32, pixel_data_size, .little); // image size
    try writer.writeInt(i32, 2835, .little); // x pixels per meter
    try writer.writeInt(i32, 2835, .little); // y pixels per meter
    try writer.writeInt(u32, 0, .little); // colors used
    try writer.writeInt(u32, 0, .little); // important colors

    // Channel masks (BGRA)
    try writer.writeInt(u32, 0x00FF0000, .little); // red mask
    try writer.writeInt(u32, 0x0000FF00, .little); // green mask
    try writer.writeInt(u32, 0x000000FF, .little); // blue mask
    try writer.writeInt(u32, 0xFF000000, .little); // alpha mask

    // Color space (LCS_sRGB)
    try writer.writeInt(u32, 0x73524742, .little); // 'sRGB'
    // CIEXYZTRIPLE endpoints (36 bytes of zeros)
    try writer.writeAll(&[_]u8{0} ** 36);
    // Gamma values (12 bytes of zeros)
    try writer.writeAll(&[_]u8{0} ** 12);

    // Pixel data (BGRA order)
    for (image.pixels) |px| {
        try writer.writeByte(px.b);
        try writer.writeByte(px.g);
        try writer.writeByte(px.r);
        try writer.writeByte(px.a);
    }
}

/// Read a BMP file into an Image. Supports 24-bit and 32-bit uncompressed BMPs.
pub fn readBmp(path: []const u8, allocator: std.mem.Allocator) !Image {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return readBmpFromReader(file.reader(), allocator);
}

/// Read BMP data from any reader.
pub fn readBmpFromReader(reader: anytype, allocator: std.mem.Allocator) !Image {
    // BMP file header
    var sig: [2]u8 = undefined;
    _ = try reader.readAll(&sig);
    if (!std.mem.eql(u8, &sig, "BM")) return error.InvalidBmp;

    _ = try reader.readInt(u32, .little); // file size
    _ = try reader.readInt(u16, .little); // reserved
    _ = try reader.readInt(u16, .little); // reserved
    const data_offset = try reader.readInt(u32, .little);

    // DIB header
    const header_size = try reader.readInt(u32, .little);
    const raw_width = try reader.readInt(i32, .little);
    const raw_height = try reader.readInt(i32, .little);
    _ = try reader.readInt(u16, .little); // planes
    const bpp = try reader.readInt(u16, .little);

    if (raw_width <= 0) return error.InvalidBmp;
    const width: u32 = @intCast(raw_width);
    const top_down = raw_height < 0;
    const height: u32 = if (top_down) @intCast(-raw_height) else @intCast(raw_height);

    if (bpp != 24 and bpp != 32) return error.UnsupportedBpp;

    // Skip remaining header bytes
    const already_read: u32 = 14 + 16; // file header (14) + what we read from DIB (16)
    const skip = data_offset - already_read;
    // Skip header_size - 12 remaining DIB bytes + any gap
    _ = header_size; // used implicitly
    try reader.skipBytes(skip, .{});

    var image = try Image.init(allocator, width, height);
    errdefer image.deinit();

    const bytes_per_pixel: u32 = @as(u32, bpp) / 8;
    const row_size = width * bytes_per_pixel;
    const padded_row = (row_size + 3) & ~@as(u32, 3);
    const pad_bytes = padded_row - row_size;

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        const row_y = if (top_down) y else height - 1 - y;
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            var pixel_buf: [4]u8 = undefined;
            _ = try reader.readAll(pixel_buf[0..bytes_per_pixel]);
            image.pixels[@as(usize, row_y) * @as(usize, width) + @as(usize, x)] = Color{
                .r = pixel_buf[2],
                .g = pixel_buf[1],
                .b = pixel_buf[0],
                .a = if (bpp == 32) pixel_buf[3] else 255,
            };
        }
        // Skip padding
        try reader.skipBytes(pad_bytes, .{});
    }

    return image;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "BMP write and read roundtrip" {
    const allocator = std.testing.allocator;
    var image = try Image.init(allocator, 4, 4);
    defer image.deinit();

    image.setPixel(0, 0, Color.red);
    image.setPixel(1, 1, Color.green);
    image.setPixel(2, 2, Color.blue);
    image.setPixel(3, 3, Color.white);

    // Write to buffer
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(allocator);
    try writeBmpToWriter(&image, buf.writer(allocator));

    // Read back
    var stream = std.io.fixedBufferStream(buf.items);
    var loaded = try readBmpFromReader(stream.reader(), allocator);
    defer loaded.deinit();

    try std.testing.expectEqual(image.width, loaded.width);
    try std.testing.expectEqual(image.height, loaded.height);
    try std.testing.expect(loaded.getPixel(0, 0).?.eql(Color.red));
    try std.testing.expect(loaded.getPixel(1, 1).?.eql(Color.green));
    try std.testing.expect(loaded.getPixel(2, 2).?.eql(Color.blue));
    try std.testing.expect(loaded.getPixel(3, 3).?.eql(Color.white));
}

test "BMP invalid signature" {
    const allocator = std.testing.allocator;
    const data = "XX\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    var stream = std.io.fixedBufferStream(data);
    const result = readBmpFromReader(stream.reader(), allocator);
    try std.testing.expectError(error.InvalidBmp, result);
}
