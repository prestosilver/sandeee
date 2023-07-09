const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");

pub const StreamError = error{
    FileMissing,
    UnknownError,
};

pub const FileStream = struct {
    path: []u8,
    contents: []u8,
    offset: u32,
    updated: bool,
    vmInstance: ?*vm.VM,

    pub fn Open(root: *files.Folder, path: []const u8, vmInstance: ?*vm.VM) !*FileStream {
        if (path.len == 0) return error.FileMissing;

        const folder = if (path[0] == '/') files.root else root;
        const file = try folder.getFile(path);

        const result = try allocator.alloc.create(FileStream);

        result.path = try allocator.alloc.alloc(u8, file.name.len);
        const cont = try file.read(vmInstance);
        result.contents = try allocator.alloc.alloc(u8, cont.len);
        result.updated = false;
        result.vmInstance = vmInstance;

        std.mem.copy(u8, result.contents, cont);
        std.mem.copy(u8, result.path, file.name);

        result.offset = 0;

        if (file.pseudoRead != null) {
            allocator.alloc.free(cont);
        }

        return result;
    }

    pub fn Read(self: *FileStream, len: u32) ![]const u8 {
        var target = @as(usize, @intCast(len));
        if (target + self.offset > self.contents.len) {
            target = self.contents.len - self.offset;
        }

        const result = try allocator.alloc.alloc(u8, target);
        const input = self.contents[self.offset .. self.offset + target];

        std.mem.copy(u8, result, input);

        self.offset += @as(u32, @intCast(target));

        return result;
    }

    pub fn Write(self: *FileStream, data: []const u8) !void {
        const targetsize = self.offset + data.len;

        self.contents = try allocator.alloc.realloc(self.contents, targetsize);

        std.mem.copy(u8, self.contents[self.offset .. self.offset + data.len], data);

        self.offset += @as(u32, @intCast(data.len));
        self.updated = true;
    }

    pub fn Flush(self: *FileStream) !void {
        if (self.updated)
            try files.root.writeFile(self.path, self.contents, self.vmInstance);
        self.updated = false;
    }

    pub fn Close(self: *FileStream) !void {
        try self.Flush();
        allocator.alloc.free(self.contents);
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
