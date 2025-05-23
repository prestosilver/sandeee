const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");

pub const StreamError = error{
    OutOfMemory,
    FileMissing,
    UnknownError,
} || files.FileError;

pub const FileStream = struct {
    path: []u8,
    contents: []u8,
    offset: u32,
    updated: bool,
    vm_instance: ?*vm.VM,

    pub fn open(root: *files.Folder, path: []const u8, vm_instance: ?*vm.VM) StreamError!*FileStream {
        if (path.len == 0) return error.FileMissing;

        const folder = if (std.mem.startsWith(u8, path, "/"))
            try (files.FolderLink.resolve(.root))
        else
            root;

        const file = try folder.getFile(path);

        const result = try allocator.alloc.create(FileStream);
        const conts = try file.read(vm_instance);

        defer if (file.data != .disk) allocator.alloc.free(conts);

        result.* = .{
            .path = try allocator.alloc.dupe(u8, file.name),
            .contents = try allocator.alloc.dupe(u8, conts),
            .updated = false,
            .vm_instance = vm_instance,
            .offset = 0,
        };

        return result;
    }

    pub fn read(self: *FileStream, len: u32) StreamError![]const u8 {
        const target = @min(self.contents.len - self.offset, len);

        const input = self.contents[self.offset .. self.offset + target];

        const result = try allocator.alloc.dupe(u8, input);

        self.offset += @as(u32, @intCast(target));

        return result;
    }

    pub fn write(self: *FileStream, data: []const u8) StreamError!void {
        const targetsize = self.offset + data.len;

        self.contents = try allocator.alloc.realloc(self.contents, targetsize);

        @memcpy(self.contents[self.offset .. self.offset + data.len], data);

        self.offset += @as(u32, @intCast(data.len));
        self.updated = true;
    }

    pub fn flush(self: *FileStream) StreamError!void {
        const root = try files.FolderLink.resolve(.root);

        if (self.updated)
            try root.writeFile(self.path, self.contents, self.vm_instance);
        self.updated = false;
    }

    pub fn deinit(self: *FileStream) void {
        if (self.updated)
            std.log.warn("Deinit stream before flush", .{});

        allocator.alloc.free(self.contents);
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }

    pub fn close(self: *FileStream) !void {
        try self.flush();
        self.deinit();
    }
};
