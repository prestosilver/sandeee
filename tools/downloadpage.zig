const std = @import("std");

pub fn create(paths: []const []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(alloc);

    try result.appendSlice("#Style @/style.eds\n\n");
    try result.appendSlice(":logo: [@/logo.eia]\n\n");
    try result.appendSlice(":center: -- Downloads --\n\n");

    var path_tab = std.StringHashMap(std.ArrayList([]const u8)).init(alloc);

    for (paths) |path| {
        const colon = std.mem.indexOf(u8, path, ":") orelse 0;
        const head = path[0..colon];
        const file = path[colon + 1 .. path.len];
        if (path_tab.getPtr(head)) |entry| {
            try entry.append(file);
        } else {
            var adds = std.ArrayList([]const u8).init(alloc);
            try adds.append(file);

            try path_tab.put(head, adds);
        }
    }

    var iter = path_tab.iterator();

    while (iter.next()) |entry| {
        try result.appendSlice(try std.fmt.allocPrint(alloc, ":hs: {s}\n\n", .{entry.key_ptr.*}));
        for (entry.value_ptr.items) |file| {
            const slash = std.mem.lastIndexOf(u8, file, "/") orelse 0;
            const dot = std.mem.lastIndexOf(u8, file, ".") orelse 0;
            var name = try alloc.dupe(u8, file[slash + 1 .. dot]);
            defer alloc.free(name);
            name[0] = std.ascii.toUpper(name[0]);
            try result.appendSlice(try std.fmt.allocPrint(alloc, ":biglink: > {s}: @{s}\n", .{ name, file }));
        }
        try result.appendSlice("\n");
    }

    try result.appendSlice(":center: -- EEE Sees all --");

    return result;
}
