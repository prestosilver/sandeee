const std = @import("std");

const lol = error{};

// struct FontChar {
//   u8: width,
//   u8: advancex,
//   u8: advancey,
// }
//
// struct FontFile {
//   u8: height,
// }

pub fn convert(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(alloc);
}
