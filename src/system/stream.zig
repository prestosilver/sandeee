const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");

pub const StreamError = error {
    FileMissing,
    UnknownError,
};

pub const FileStream = struct {
    path: []u8,
    contents: []u8,
    offset: u32,

    pub fn Open(path: []const u8) !*FileStream {
        var result = try allocator.alloc.create(FileStream);

        var file = files.root.getFile(path);
        if (file == null) {
            return error.FileMissing;
        }

        result.path = try allocator.alloc.alloc(u8, path.len);
        result.contents = try allocator.alloc.alloc(u8, file.?.contents.len);
        std.mem.copy(u8, result.contents, file.?.contents);
        std.mem.copy(u8, result.path, path);

        result.offset = 0;

        return result;
    }

    pub fn Read(self: *FileStream, len: u32) ![]const u8 {
        var target = @intCast(usize, len);
        if (target + self.offset > self.contents.len) {
            target = self.contents.len - self.offset;
        }

        var result = try allocator.alloc.alloc(u8, target);

        std.mem.copy(u8, result, self.contents[self.offset..self.offset + target]);

        self.offset += @intCast(u32, target);

        return result;
    }

    pub fn Write(self: *FileStream, data: []const u8) !void {
        var targetsize = self.offset + data.len;

        if (self.contents.len < targetsize) {
            self.contents = try allocator.alloc.realloc(self.contents, targetsize);
        }

        std.mem.copy(u8, self.contents[self.offset..self.offset + data.len], data);
    }

    pub fn Flush(self: *FileStream) !void {
        if (!files.writeFile(self.path, self.contents))
            return error.UnknownError;
    }

    //pub fn Close(self: *FileStream) !void {
    //    self.Flush();
    //    allocator.alloc.free(self);
    //}
};
