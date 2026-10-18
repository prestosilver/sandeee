const std = @import("std");

fn checkSize(Self: type, comptime expected: usize) void {
    if (@sizeOf(Self) != expected) {
        const info = @typeInfo(Self);

        var pos: usize = 0;

        for (
            info.@"struct".field_types,
            info.@"struct".field_names,
        ) |T, name| {
            const offset = @offsetOf(Self, name);
            @compileLog(std.fmt.comptimePrint(
                "{s}[{}] {}: {}",
                .{ @sizeOf(T), name, offset, pos },
            ));
            pos += @sizeOf(T);
        }

        @compileError(std.fmt.comptimePrint(
            "This is super bad, the {} type is not the right size got {} expected {} ({})",
            .{ @typeName(Self), @sizeOf(Self), expected, @typeInfo(Self) },
        ));
    }
}

const Header = extern struct {
    file_size: u32,
    magic: u16 = 0xA5E0,
    frames: u16,
    width: u16,
    height: u16,
    color_depth: enum(u16) {
        rgba = 32,
        grayscale = 16,
        indexed = 8,
    },
    flags: packed struct(u32) {
        opacity_valid: bool,
        blend_valid: bool,
        layers_uuid: bool,
        _: u29,
    } align(1),
    speed: u16,
    _0: u32,
    _1: u32,
    value: u8,
    _2: [3]u8,
    color_count: u16,
    pixel_width: u8,
    pixel_height: u8,
    grid_x: i16,
    grid_y: i16,
    grid_width: u16,
    grid_height: u16,
    _3: [84]u8,

    comptime {
        checkSize(@This(), 128);
    }
};

const Frame = struct {
    chunks: []Chunk,

    pub const Header = extern struct {
        bytes: u32,
        magic: [2]u8,
        chunks: u16,
        duration: u16,
        _1: [2]u8,
        new_chunks: u32,

        comptime {
            checkSize(@This(), 16);
        }
    };

    pub const Chunk = struct {
        pub const Data = extern union {
            cel: extern struct {
                layer_index: u16,
                x_position: i16,
                y_position: i16,
                opacity: u8 align(1),
                kind: enum(u16) {
                    raw = 0,
                    linked = 1,
                    compressed_image = 2,
                    compressed_tilemap = 3,
                    _,
                } align(1),
                z: i16 align(1),
                _1: [5]u8 align(1),
                data: extern union {
                    raw: extern struct {
                        width: u16 align(1),
                        height: u16 align(1),
                        /// HACK: this caps the size and uses a ton of memory
                        pixels: [8192]u8,
                    },
                    linked: u16,
                    compressed_image: extern struct {
                        width: u16 align(1),
                        height: u16 align(1),
                        /// HACK: this caps the size and uses a ton of memory
                        pixels: [8192]u8,
                    },
                } align(1),

                comptime {
                    if (@offsetOf(@This(), "data") != 16) {
                        @compileError(std.fmt.comptimePrint(
                            "This is super bad, the offset of data in Chunk.Data is {} not {}",
                            .{ @offsetOf(@This(), "data"), 16 },
                        ));
                    }
                }
            },
        };

        size: u32,
        kind: enum(u16) {
            old_palette_a = 0x0004,
            old_palette_b = 0x0011,
            layer = 0x2004,
            cel = 0x2005,
            cel_extra = 0x2006,
            color_profile = 0x2007,
            external_files = 0x2008,
            mask_deprecated = 0x2016,
            path = 0x2017,
            tags = 0x2018,
            palette = 0x2019,
            user_data = 0x2020,
            slice = 0x2022,
            tileset = 0x2023,
        },
        data: Data align(1),
    };

    pub fn deinit(self: Frame, allocator: std.mem.Allocator) void {
        allocator.free(self.chunks);
    }
};

// converts a png to a eia
pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();

    const input_path = args.next() orelse return error.MissingInputFile;
    const output_path = args.next() orelse return error.MissingOutputFile;

    var output_file = try std.Io.Dir.cwd().createFile(init.io, output_path, .{});
    defer output_file.close(init.io);

    var writer = output_file.writer(init.io, &.{});

    var input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);

    var reader_buffer: [1024]u8 = undefined;
    var reader = input_file.reader(init.io, &reader_buffer);

    const header = try reader.interface.takeStruct(Header, .little);

    var frames: std.ArrayList(Frame) = .fromOwnedSlice(&.{});
    defer {
        for (frames.items) |frame|
            frame.deinit(init.gpa);

        frames.deinit(init.gpa);
    }

    const pre_read_size = @sizeOf(u32) + @sizeOf(u16);

    while (reader.interface.takeStruct(Frame.Header, .little)) |frame_header| {
        var chunks: std.ArrayList(Frame.Chunk) = .fromOwnedSlice(&.{});
        defer chunks.deinit(init.gpa);

        for (0..frame_header.chunks) |_| {
            const chunk_size = try reader.interface.takeInt(u32, .little);
            const chunk_kind = try reader.interface.takeInt(u16, .little);

            try chunks.append(init.gpa, .{
                .size = chunk_size,
                .kind = @fromBackingInt(chunk_kind),
                .data = undefined,
            });

            try reader.interface.readSliceAll(std.mem.asBytes(&chunks.lastPtr().?.data)[0 .. chunk_size - pre_read_size]);
        }

        try frames.append(init.gpa, .{
            .chunks = try chunks.toOwnedSlice(init.gpa),
        });
    } else |err| {
        switch (err) {
            else => {},
        }
    }

    var max_layers: usize = 1;

    for (frames.items) |frame| {
        var layers: usize = 0;
        for (frame.chunks) |chunk| {
            if (chunk.kind == .layer)
                layers += 1;
        }

        max_layers = @max(max_layers, layers);
    }

    const width: u16 = @intCast(header.width * frames.items.len);
    const height: u16 = @intCast(header.height * max_layers);

    var data = try init.gpa.alloc(u32, @as(usize, @intCast(width)) * @as(usize, @intCast(height)));
    defer init.gpa.free(data);

    @memset(data, 0);

    for (frames.items, 0..) |frame, frame_idx| {
        for (frame.chunks) |chunk| {
            switch (chunk.kind) {
                .cel => {
                    const cel = &chunk.data.cel;

                    const sprite_x = frame_idx * header.width;
                    const sprite_y = cel.layer_index * header.height;

                    switch (cel.kind) {
                        .raw => {
                            var fbs = std.Io.Reader.fixed(cel.data.raw.pixels[0 .. chunk.size - pre_read_size - 16 - 4]);

                            for (0..cel.data.raw.height) |y_offset| {
                                for (0..cel.data.raw.width) |x_offset| {
                                    const x = @as(usize, @intCast(cel.x_position)) + x_offset + sprite_x;
                                    const y = @as(usize, @intCast(cel.y_position)) + y_offset + sprite_y;
                                    data[y * width + x] = try fbs.takeInt(u32, .little);
                                }
                            }
                        },
                        .compressed_image => {
                            var decomp_buffer: [32768 * 2]u8 = undefined;

                            var fbs = std.Io.Reader.fixed(cel.data.compressed_image.pixels[0 .. chunk.size - pre_read_size - 16 - 4]);
                            var decompressor = std.compress.flate.Decompress.init(&fbs, .zlib, &decomp_buffer);

                            for (0..cel.data.compressed_image.height) |y_offset| {
                                for (0..cel.data.compressed_image.width) |x_offset| {
                                    const x = @as(usize, @intCast(cel.x_position)) + x_offset + sprite_x;
                                    const y = @as(usize, @intCast(cel.y_position)) + y_offset + sprite_y;
                                    data[y * width + x] = try decompressor.reader.takeInt(u32, .little);
                                }
                            }
                        },
                        else => return error.TODO,
                    }
                },

                //else => std.log.info("unknown layer kind {s}", .{@tagName(chunk.kind)}),
                else => {},
            }
        }
    }

    try writer.interface.writeAll("eimg");

    try writer.interface.writeAll(&std.mem.toBytes(width));
    try writer.interface.writeAll(&std.mem.toBytes(height));
    try writer.interface.writeAll(std.mem.sliceAsBytes(data));
}
