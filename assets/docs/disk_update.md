# possible disk image spec

## data layout

```rs
// Creates a max size static array with attached header data given size bytes 
comptime fn MaxLength(comptime size: usize, comptime header: type, comptime Data: type) type {
    @compileError("Unimplemented");
}
pub const Disk = struct {
    const BLOCK_SIZE: usize = 4096;
    const FatOffset = i16;

    const Block = union {
        meta: struct {
            full_name: [128]u8,
            created: usize = 0,
            modified: usize = 0,

            const MetaBlock = @This();

            pub comptime fn init_comptime(comptime name: anytype) MetaBlock {
                // This should ensure name is an array type (non slice) with len < 128
                @compileError("Unimplemented");
            }
        },
        root: struct {
            magic: [4]u8 = "EEED",
            root_empty: FatOffset,
            root_folder: FatOffset,
        },
        empty: struct {
            // dont need to be too particular on space since this is empty
            next_empty: i64 = 0,
            count: usize = 1,
        },
        folder: MaxLength(
            BLOCK_SIZE,
            enum(FatOffset) { eof = 0, _ },
            struct {
                tags: packed struct {
                    exists: bool = false,
                    is_folder: bool = undefined,
                    hidden: bool = undefined,
                    padding: u5 = undefined,
                },
                item_name: [15]u8 = undefined,
                meta_offset: FatOffset = undefined,
                data_offset: FatOffset = undefined,
            },
        ),
        file: MaxLength(
            BLOCK_SIZE,
            enum(FatOffset) { eof = 0, _ },
            struct {
                data: FatOffset = undefined,
                data_len: u32 = 0,
            },
        ),
        data: [BLOCK_SIZE]u8,
    };

    const CacheIdx = u6;
    const CacheBlockIdx = u4;

    // Alignment needs to be 4096
    allocator: std.mem.Allocator,
    cache_meta: [std.math.maxInt(CacheIdx)]struct {
        valid: bool,
        idx: CacheIdx,
    },
    cache_data: *align(4096) [std.math.maxInt(CacheIdx)][std.math.maxInt(CacheBlockIdx)]Block,
    disk_file: std.fs.File,

    /// A folder object
    pub const Folder: struct {
        name: []const u8,
        meta_block: usize,
        disk: usize,

        /// gathers pointers to the blocks in a file and returns it
        pub fn openFile() !File {
            @compileError("Unimplemented");
        }

        /// searches for a folder and opens it
        pub fn openFolder() !Folder {
            @compileError("Unimplemented");
        }

        pub fn deinit() void {
            // Should free name
            // dont free disk (thats the parent)
        }
    };

    /// A file object
    pub const File: struct {
        name: []const u8,
        meta_block: usize,
        data_blocks: []usize,
        disk: *Disk,

        pub fn deinit() void {
            // Should free name
            // Should free data block storage
            // dont free disk (thats the parent)
        }
    };

    /// Returns a pointer to the block at index idx
    fn getBlock(self: *Disk, idx: usize) *Block {
        @compileError("Unimplemented");
    }

    /// Returns the root folder of a disk
    pub fn root(self: *Disk) Folder {
        const root_block = self.getBlock(0);

        return .{
            .name = "",
            .meta_block = root_block.root.root_folder,
        };
    }

    /// resizes a disk and returns the index of the first empty
    pub fn grow(self: *Disk, count: usize) !usize {
        // careful of realloc
        @compileError("Unimplemented");
    }

    /// resizes a disk and returns the index of the first empty
    pub fn allocBlocks(self: *Disk, start: usize, count: usize) !void {
        // careful of realloc
        @compileError("Unimplemented");
    }

    /// marks count sequential blocks as used
    /// returns the index of the first block
    /// can grow the disk if needed
    pub fn allocBlocks(self: *Disk, count: usize) !usize {
        // get free block from root
        // if free is the right size or bigger split it and return+set
        // if free is too small go to next free and repeat
        // if no free segment is big enough, grow to have correct size
        @compileError("Unimplemented");
    }

    pub fn init(allocator: std.mem.Allocator, file: std.io.File) !Disk {
        // read file into disk
        // init cache
        // make sure magic matches, upgrade disk if needed
        @compileError("Unimplemented");
    }

    pub fn deinit(self: *Disk) void {
        // free cache
        // free file
        @compileError("Unimplemented");
    }

    /// an empty disk object, for fast creation
    const BLANK_DISK = [_]Block{
        .{
            .root = .{
                .root_empty = 2,
                .root_folder = 3,
            },
        },
        .{ .meta = .init_comptime(NAME) },
        .{ .empty = .{} },
        .{ .folder = .{} },
    };
};

comptime if (@sizeOf(Block) != BlockSize) @compileError("This is super bad, the block type is not the right size");

```

## algs

### File creation

```nim
    folder_block = root.get_path(target_folder)
    do:
        for i in folder_block.folder.items:
            if i.kind == file and i.meta.name == target_name:
                return File exists error
    while block = block.folder.next
    if block.folder.items[last].is_used:
        create
```

### File deletion

```nim
    folder_block = root.get_path(target_folder)
    do:
        for item in folder_block.folder.items:
            if item.kind == file and item.meta.name == target_name:
                # first we free meta
                meta_block = item + item.meta_offset
                meta_block.empty.size = total_blocks

                file_block = item + item.data_offset
                root.empty = file_block
                // TODO: free all blocks in file
    while block = block.folder.next

    else: return File not exist error
```

### Flush file

```nim
```
