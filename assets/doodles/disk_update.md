# possible disk image spec

## data layout

```rs
const BLOCK_SIZE: usize = 4096;
const FatOffset = i16;

// Creates a max size static array with attached header data given size bytes 
comptime fn MaxLength(comptime size: usize, comptime header: type, comptime Data: type) type {
    @compileError("Unimplemented");
}
const Disk = struct {
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

    blocks: [*]Block,
        
    const BLANK_DISK: Disk = .{
        .blocks = .{
            .{
                .root = .{
                    .root_empty = 2,
                    .root_folder = 3,
                },
            },
            .{ .meta = .init_comptime(NAME) },
            .{ .empty = .{} },
            .{ .folder = .{} },
        },
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