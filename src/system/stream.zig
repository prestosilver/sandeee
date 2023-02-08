const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");

pub const FileStream = struct {
    path: []const u8,
    contents: []const u8,
    offset: u8,

    pub fn Open(path: []const u8) !*FileStream {
        var result = allocator.alloc.create(FileStream);

        result.path = path;
        result.contents = files.root.getFile(path).contents;

        return result;
    }

//    pub fn Read(self: *FileStream, len: u8) ![]const u8 {
//
//    }
//
//    pub fn Write(self: *FileStream, data: []const u8) !void {
//
//    }
//
//    pub fn Flush(self: *FileStream) !void {
//
//    }
//
//    pub fn Close(self: *FileStream) !void {
//
//    }
};
