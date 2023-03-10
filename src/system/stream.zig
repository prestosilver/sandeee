const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");

pub const StreamError = error{
    FileMissing,
    UnknownError,
};

pub const FileStream = struct {
    path: []u8,
    contents: []u8,
    offset: u32,

    pub fn Open(root: *files.Folder, path: []const u8) !*FileStream {
        var result = try allocator.alloc.create(FileStream);

        var folder = root;
        if (path[0] == '/') {
            folder = files.root;
        }
        var file = folder.getFile(path);

        if (file == null) {
            allocator.alloc.destroy(result);

            return error.FileMissing;
        }

        result.path = try allocator.alloc.alloc(u8, file.?.name.len);
        var cont = file.?.read();
        result.contents = try allocator.alloc.alloc(u8, cont.len);

        std.mem.copy(u8, result.contents, cont);
        std.mem.copy(u8, result.path, file.?.name);

        result.offset = 0;

        if (file.?.pseudoRead != null) {
            allocator.alloc.free(cont);
        }

        return result;
    }

    pub fn Read(self: *FileStream, len: u32) ![]const u8 {
        var target = @intCast(usize, len);
        if (target + self.offset > self.contents.len) {
            target = self.contents.len - self.offset;
        }

        var result = try allocator.alloc.alloc(u8, target);
        var input = self.contents[self.offset .. self.offset + target];

        std.mem.copy(u8, result, input);

        self.offset += @intCast(u32, target);

        return result;
    }

    pub fn Write(self: *FileStream, data: []const u8) !void {
        var targetsize = self.offset + data.len;

        if (self.contents.len < targetsize) {
            self.contents = try allocator.alloc.realloc(self.contents, targetsize);
        }

        std.mem.copy(u8, self.contents[self.offset .. self.offset + data.len], data);

        self.offset += @intCast(u32, data.len);
    }

    pub fn Flush(self: *FileStream) !void {
        try files.root.writeFile(self.path, self.contents);
    }

    pub fn Close(self: *FileStream) !void {
        try self.Flush();
        allocator.alloc.free(self.contents);
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
