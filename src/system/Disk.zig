const std = @import("std");
const log = @import("../util/log.zig");

const Disk = @This();

fn strSlice(slice: []const u8) []const u8 {
    for (slice, 0..) |item, idx|
        if (item == 0) return slice[0..idx];
    return slice;
}

fn MaxLength(comptime size: usize, comptime Header: type, comptime Data: type) type {
    const header_size = @sizeOf(Header);

    const data_size = @sizeOf(Data);
    const data_align = @alignOf(Data);

    const data_size_align = (std.math.divCeil(usize, data_size, data_align) catch unreachable) * data_align;

    const data_start = (std.math.divCeil(usize, header_size, data_align) catch unreachable) * data_align;

    const fill_size = size - data_start;

    const data_len = @divFloor(fill_size, data_size_align);

    return extern struct {
        header: Header,
        data: [data_len]Data = undefined,

        const Self = @This();

        pub fn init(comptime header: Header, comptime data: []const Data) Self {
            var tmp: Self = .{ .header = header };
            inline for (data, 0..) |item, idx| {
                tmp.data[idx] = item;
            }

            return tmp;
        }
    };
}

const BLOCK_SIZE: usize = 4096;
const FatOffset = i32;

const Block = extern union {
    meta: extern struct {
        full_name: [128]u8,
        created: usize = 0,
        modified: usize = 0,

        const MetaBlock = @This();

        pub fn init(comptime name: anytype) MetaBlock {
            var result: MetaBlock = .{ .full_name = undefined };
            for (name, 0..) |ch, idx| {
                result.full_name[idx] = ch;
            }

            result.full_name[name.len] = 0;

            return result;
        }
    },
    root: extern struct {
        magic: [4]u8 = .{ 'E', 'E', 'E', 'D' },
        root_meta: FatOffset,
        root_empty: FatOffset,
        root_folder: FatOffset,
        length: usize,
    },
    empty: extern struct {
        // dont need to be too particular on space since this is empty
        next_empty: i64 = 0,
        count: usize = 1,
    },
    folder: MaxLength(
        BLOCK_SIZE,
        enum(FatOffset) { eof = 0, _ },
        extern struct {
            tags: packed struct(u8) {
                exists: bool = false,
                is_folder: bool = undefined,
                hidden: bool = undefined,
                padding: u5 = undefined,
            },
            item_name: [16]u8 = undefined,
            meta_offset: FatOffset = undefined,
            data_offset: FatOffset = undefined,
        },
    ),
    file: MaxLength(
        BLOCK_SIZE,
        enum(FatOffset) { eof = 0, _ },
        extern struct {
            data: FatOffset = 0,
            data_len: u32 = 0,
        },
    ),
    data: [BLOCK_SIZE]u8,
};

const CacheIdx = u6;
const CacheBlockIdx = u10;

const CACHE_LEN = std.math.maxInt(CacheIdx);

const CacheMeta = packed struct {
    valid: bool = false,
    idx: CacheIdx = undefined,
};

// Alignment needs to be 4096
allocator: std.mem.Allocator,
io: std.Io,
cache_meta: [CACHE_LEN]CacheMeta = [_]CacheMeta{.{}} ** CACHE_LEN,
cache_data: [std.math.maxInt(CacheIdx)]Block align(BLOCK_SIZE) = undefined,
disk_file: std.Io.File,

/// A folder object
pub const Folder = struct {
    name: [16]u8,
    meta_block: usize,
    data_block: usize,
    disk: *Disk,

    /// gathers pointers to the blocks in a file and returns it
    pub fn openFile(self: *const Folder, path: []const u8) !File {
        var iter = self.iterator();
        while (iter.next()) |item| {
            if (item == .file) {
                if (std.mem.eql(u8, path, strSlice(&item.file.name)))
                    return item.file;
            }
        }

        return error.FolderNotFound;
    }

    /// searches for a folder and opens it
    pub fn openFolder(self: *const Folder, folder_name: []const u8) !Folder {
        const internal_name = folder_name[0..@min(15, folder_name.len)];

        var iter = self.iterator();
        while (iter.next()) |item| {
            if (item == .folder) {
                const tmp_name = strSlice(&item.folder.name);

                if (std.mem.eql(u8, internal_name, tmp_name[0..@min(15, tmp_name.len)])) {
                    if (folder_name.len < 16)
                        return item.folder;

                    const meta = item.folder.getMeta();
                    if (std.mem.eql(u8, strSlice(&meta.meta.full_name), folder_name))
                        return item.folder;
                }
            }
        }

        return error.FolderNotFound;
    }

    pub fn createFile(self: *const Folder, file_name: []const u8) File {
        const internal_name = file_name[0..@min(15, file_name.len)];

        var name_idx: u8 = '!';

        var iter = self.iterator();
        while (iter.next()) |item| {
            if (item == .file) {
                const tmp_name = strSlice(&item.file.name);

                if (std.mem.eql(u8, internal_name, tmp_name[0..@min(15, tmp_name.len)])) {
                    if (file_name.len < 16)
                        return item.file;

                    name_idx += 1;

                    const meta = item.file.getMeta();
                    if (std.mem.eql(u8, strSlice(&meta.meta.full_name), file_name))
                        return item.file;
                }
            }
        }

        var name: [16]u8 = [_]u8{0} ** 16;
        for (file_name, 0..) |ch, idx| {
            if (idx < 15)
                name[idx] = ch;
        }
        name[15] = name_idx;

        const block_idx = self.disk.allocBlocks(2);
        const meta = self.disk.getBlock(block_idx + 1);
        @memcpy(meta.meta.full_name[0..file_name.len], file_name);
        meta.meta.full_name[file_name.len + 1] = 0;

        const block = self.disk.getBlock(block_idx);
        for (&block.file.data) |*data| {
            data.data = 0;
        }

        const data_block = self.disk.getBlock(self.data_block);
        for (&data_block.folder.data) |*entry| {
            if (!entry.tags.exists) {
                entry.* = .{
                    .tags = .{
                        .exists = true,
                        .is_folder = false,
                        .hidden = false,
                    },
                    .item_name = name,
                    .meta_offset = @intCast(block_idx + 1 - @as(usize, @intCast(self.data_block))),
                    .data_offset = @intCast(block_idx - @as(usize, @intCast(self.data_block))),
                };

                return .{
                    .disk = self.disk,
                    .name = name,
                    .data_block = block_idx,
                    .meta_block = block_idx + 1,
                    .cont_blocks = &.{},
                };
            }
        }

        @panic("Unimplemented");
    }

    /// searches for a folder, creating it if it dosent exist.
    /// opens the folder afterwards
    pub fn createFolder(self: *const Folder, folder_name: []const u8) Folder {
        const internal_name = folder_name[0..@min(15, folder_name.len)];

        var name_idx: u8 = '!';

        var iter = self.iterator();
        while (iter.next()) |item| {
            if (item == .folder) {
                const tmp_name = strSlice(&item.folder.name);

                if (std.mem.eql(u8, internal_name, tmp_name[0..@min(15, tmp_name.len)])) {
                    if (folder_name.len < 16)
                        return item.folder;

                    name_idx += 1;

                    const meta = item.folder.getMeta();
                    if (std.mem.eql(u8, strSlice(&meta.meta.full_name), folder_name))
                        return item.folder;
                }
            }
        }

        var name: [16]u8 = [_]u8{0} ** 16;
        for (folder_name, 0..) |ch, idx| {
            if (idx < 15)
                name[idx] = ch;
        }
        name[15] = name_idx;

        const block_idx = self.disk.allocBlocks(2);

        const meta = self.disk.getBlock(block_idx + 1);
        @memcpy(meta.meta.full_name[0..folder_name.len], folder_name);
        meta.meta.full_name[folder_name.len + 1] = 0;

        const block = self.disk.getBlock(block_idx);
        for (&block.folder.data) |*data| {
            data.tags.exists = false;
        }

        const data_block = self.disk.getBlock(self.data_block);
        for (&data_block.folder.data) |*entry| {
            if (!entry.tags.exists) {
                entry.* = .{
                    .tags = .{
                        .exists = true,
                        .is_folder = true,
                        .hidden = false,
                    },
                    .item_name = name,
                    .data_offset = @intCast(block_idx - @as(usize, @intCast(self.data_block))),
                    .meta_offset = @intCast(block_idx + 1 - @as(usize, @intCast(self.data_block))),
                };

                return .{
                    .disk = self.disk,
                    .name = name,
                    .data_block = block_idx,
                    .meta_block = block_idx + 1,
                };
            }
        }

        @panic("Unimplemented");
    }

    const Iterator = struct {
        disk: *Disk,
        data_block: ?usize,
        data_block_entry: usize = 0,

        const Entry = union(enum) {
            file: File,
            folder: Folder,
        };

        pub fn next(self: *Iterator) ?Entry {
            const data_block = self.data_block orelse return null;

            const block = self.disk.getBlock(data_block).folder;
            const data_block_entry = self.data_block_entry;

            self.data_block_entry += 1;
            if (self.data_block_entry >= block.data.len) {
                self.data_block_entry = 0;

                self.data_block = if (block.header == .eof)
                    null
                else
                    @as(usize, @intCast(@intFromEnum(block.header))) + data_block;
            }

            const entry = block.data[data_block_entry];

            if (!entry.tags.exists)
                return self.next();

            if (entry.tags.is_folder) {
                return .{
                    .folder = .{
                        .meta_block = @as(usize, @intCast(entry.meta_offset)) + data_block,
                        .data_block = @as(usize, @intCast(entry.data_offset)) + data_block,
                        .name = entry.item_name,
                        .disk = self.disk,
                    },
                };
            }

            return .{
                .file = .init(
                    self.disk,
                    entry.item_name,
                    @as(usize, @intCast(entry.data_offset)) + data_block,
                    @as(usize, @intCast(entry.meta_offset)) + data_block,
                ),
            };
        }
    };

    pub fn iterator(self: *const Folder) Iterator {
        return .{
            .disk = self.disk,
            .data_block = self.data_block,
        };
    }

    pub fn fullName(self: *const Folder) []const u8 {
        return strSlice(&self.getMeta().meta.full_name);
    }

    pub fn getMeta(self: *const Folder) *align(4096) Block {
        return self.disk.getBlock(self.meta_block);
    }
};

/// A file object
pub const File = struct {
    name: [16]u8,
    meta_block: usize,
    data_block: usize,
    cont_blocks: []usize,
    disk: *Disk,

    pub fn init(disk: *Disk, name: [16]u8, data_block_idx: usize, meta_block_idx: usize) File {
        var cont_blocks: std.ArrayList(usize) = .empty;

        var idx: ?usize = data_block_idx;
        while (idx) |index| {
            const next_block = disk.getBlock(index).file;

            defer idx = if (next_block.header == .eof)
                null
            else
                idx.? + @as(usize, @intCast(@intFromEnum(next_block.header)));

            for (next_block.data) |entry| {
                if (entry.data != 0) {
                    const data_idx = @as(usize, @intCast(entry.data)) + index;
                    cont_blocks.append(disk.allocator, data_idx) catch unreachable;
                }
            }
        }

        return .{
            .meta_block = meta_block_idx,
            .data_block = data_block_idx,
            .cont_blocks = cont_blocks.toOwnedSlice(disk.allocator) catch unreachable,
            .disk = disk,
            .name = name,
        };
    }

    pub fn fullName(self: *const File) []const u8 {
        return strSlice(&self.getMeta().meta.full_name);
    }

    pub fn getMeta(self: *const File) *align(4096) Block {
        return self.disk.getBlock(self.meta_block);
    }

    pub fn deinit(self: *const File) void {
        self.disk.allocator.free(self.cont_blocks);
    }
};

/// Returns a pointer to the block at index idx
fn getBlock(self: *Disk, idx: usize) *align(BLOCK_SIZE) Block {
    const cache_index_clipped: CacheIdx = @truncate(idx);
    const cache_index: usize = @intCast(cache_index_clipped);

    if (self.cache_meta[cache_index].valid and self.cache_meta[cache_index].idx ==
        @as(CacheBlockIdx, @truncate(idx >> @bitSizeOf(CacheIdx))))
    {
        return &self.cache_data[cache_index];
    } else {
        const cache_data = &self.cache_data[cache_index].data;

        if (self.cache_meta[cache_index].valid) {
            _ = self.disk_file.writePositionalAll(self.io, cache_data, BLOCK_SIZE *
                (cache_index + (@as(usize, @intCast(self.cache_meta[cache_index].idx)) << @bitSizeOf(CacheIdx)))) catch 0;
        }

        _ = self.disk_file.readPositionalAll(self.io, cache_data, BLOCK_SIZE * idx) catch 0;

        self.cache_meta[cache_index] = .{
            .valid = true,
            .idx = @truncate(idx >> @bitSizeOf(CacheIdx)),
        };

        return &self.cache_data[cache_index];
    }
}

/// Returns the root folder of a disk
pub fn root(self: *Disk) Folder {
    const root_block = self.getBlock(0);

    return .{
        .disk = self,
        .name = std.mem.zeroes([16]u8),
        .data_block = @intCast(0 + root_block.root.root_folder),
        .meta_block = @intCast(0 + root_block.root.root_meta),
    };
}

pub fn grow(self: *Disk, count: usize) usize {
    const result = self.getBlock(0).root.length;
    self.getBlock(0).root.length += count;

    return result;
}

/// marks count sequential blocks as used
/// returns the index of the first block
/// can grow the disk if needed
pub fn allocBlocks(self: *Disk, count: usize) usize {
    const free = self.getBlock(0).root.root_empty;
    while (free != 0) {}

    return self.grow(count);
}

pub fn init(io: std.Io, allocator: std.mem.Allocator, file: std.Io.File) !Disk {
    var self: Disk = .{
        .io = io,
        .allocator = allocator,
        .disk_file = file,
    };
    const root_block = self.getBlock(0).root;
    std.debug.assert(std.mem.eql(u8, &root_block.magic, &.{ 'E', 'E', 'E', 'D' }));

    // init cache
    // make sure magic matches, upgrade disk if needed
    return self;
}

pub fn deinit(self: *Disk) void {
    for (self.cache_meta, 0..) |meta, idx|
        if (meta.valid) {
            _ = self.disk_file.writePositionalAll(self.io, &self.cache_data[idx].data, BLOCK_SIZE *
                (idx + (@as(usize, @intCast(meta.idx)) << @bitSizeOf(CacheIdx)))) catch 0;
        };
}

/// an empty disk object, for fast creation
const BLANK_DISK = [_]Block{
    .{
        .root = .{
            .root_meta = 1,
            .root_empty = 0,
            .root_folder = 2,
            .length = 3,
        },
    },
    .{ .meta = .init("SandEEE OS") },
    .{ .folder = .init(.eof, &.{}) },
};

comptime {
    if (@sizeOf(Block) > BLOCK_SIZE) {
        @compileError(std.fmt.comptimePrint(
            "This is super bad, the block type is not the right size got {} expected {} ({})",
            .{ @sizeOf(Block), BLOCK_SIZE, @typeInfo(Block) },
        ));
    }
}

test "disk works" {
    {
        var file = try std.Io.Dir.cwd().createFile(std.testing.io, "tmp.eee", .{});
        defer file.close(std.testing.io);

        var buf: [1024]u8 = undefined;
        var writer = file.writer(std.testing.io, &buf);
        try writer.interface.writeAll(&std.mem.toBytes(BLANK_DISK));
    }

    var file = try std.Io.Dir.cwd().openFile(std.testing.io, "tmp.eee", .{
        .mode = .read_write,
    });
    defer file.close(std.testing.io);

    var tmp: Disk = try .init(std.testing.io, std.testing.allocator, file);
    defer tmp.deinit();

    const disk_root = tmp.root();

    try std.testing.expectEqualStrings(strSlice(&disk_root.name), "");
    {
        var iter = disk_root.iterator();
        while (iter.next()) |entry| {
            switch (entry) {
                .file => |the_file| {
                    log.log.warn("File {s}", .{strSlice(&the_file.name)});
                },
                .folder => |the_folder| {
                    log.log.warn("Folder {s}", .{strSlice(&the_folder.name)});
                },
            }
        }
    }

    _ = disk_root.createFolder("FDSFDSFDSFDSFDSFDSFDSAAAAAAAA");
    _ = disk_root.createFolder("FDSFDSFDSFDSFDSFDSFDSABBBBBBB");
    _ = disk_root.createFolder("FDSFDSFDSFDSFDSFDSFDSACCCCCCC");
    _ = disk_root.createFolder("TESTA");
    _ = disk_root.createFolder("TESTB");
    _ = disk_root.createFolder("TESTC");
    _ = disk_root.createFolder("TESTD");
    _ = disk_root.createFolder("TESTE");

    const new_file = disk_root.createFile("FileTest");
    defer new_file.deinit();

    const sub_folder = try disk_root.openFolder("TESTA");
    const sub_sub_folder = sub_folder.createFolder("TESTF");

    log.log.warn("Folder block {}", .{sub_folder.data_block});
    log.log.warn("Sub Sub Folder block {}", .{sub_sub_folder.data_block});

    const b_sub_folder = try disk_root.openFolder("FDSFDSFDSFDSFDSFDSFDSACCCCCCC");
    const b_sub_sub_folder = b_sub_folder.createFolder("TESTF");

    try std.testing.expectEqualStrings(b_sub_folder.fullName(), "FDSFDSFDSFDSFDSFDSFDSACCCCCCC");

    log.log.warn("Folder block {}", .{b_sub_folder.data_block});
    log.log.warn("Sub Sub Folder block {}", .{b_sub_sub_folder.data_block});

    {
        var iter = disk_root.iterator();
        while (iter.next()) |entry| {
            switch (entry) {
                .file => |the_file| {
                    log.log.warn("File {s} meta {any}", .{ the_file.fullName(), the_file.getMeta().meta });
                },
                .folder => |the_folder| {
                    log.log.warn("Folder {s} {s}", .{ strSlice(&the_folder.name), the_folder.fullName() });
                },
            }
        }
    }
}
