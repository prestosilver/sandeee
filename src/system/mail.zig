const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");

pub var emails: std.ArrayList(Email) = undefined;

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub fn checkLine(line: []const u8, start: []const u8) bool {
    if (line.len < start.len) return false;

    for (start, 0..) |char, idx|
        if (char != line[idx]) return false;

    return true;
}

pub fn append(e: Email) !void {
    try emails.append(e);
}

pub fn toStr() ![]u8 {
    var result = try allocator.alloc.alloc(u8, 4);

    var len = std.mem.toBytes(emails.items.len)[0..4];
    std.mem.copy(u8, result, len);
    for (emails.items) |email| {
        var start = result.len;

        var idStr = std.mem.toBytes(email.id);
        var boxStr = std.mem.toBytes(email.box);
        var fromLen = std.mem.toBytes(email.from.len)[0..4];
        var subjectLen = std.mem.toBytes(email.subject.len)[0..4];
        var contentLen = std.mem.toBytes(email.contents.len)[0..4];

        var appends = try std.fmt.allocPrint(
            allocator.alloc,
            "{s}{s}{s}{s}{s}{s}{s}{s}",
            .{
                idStr,
                boxStr,
                fromLen,
                email.from,
                subjectLen,
                email.subject,
                contentLen,
                email.contents,
            },
        );
        defer allocator.alloc.free(appends);

        result = try allocator.alloc.realloc(result, start + appends.len);

        std.mem.copy(u8, result[start..], appends);
    }
    return result;
}

pub fn parseTxt(file: std.fs.File) !Email {
    var result = Email{
        .from = "",
        .subject = "",
        .contents = "",
    };

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var contents = std.ArrayList(u8).init(allocator.alloc);
    defer contents.deinit();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (checkLine(line, "id: ")) {
            result.id = try std.fmt.parseInt(u8, line[4..], 0);
        } else if (checkLine(line, "box: ")) {
            result.box = try std.fmt.parseInt(u8, line[5..], 0);
        } else if (checkLine(line, "from: ")) {
            var sub = try allocator.alloc.alloc(u8, line.len - 6);
            std.mem.copy(u8, sub, line[6..]);
            result.from = sub;
        } else if (checkLine(line, "sub: ")) {
            var sub = try allocator.alloc.alloc(u8, line.len - 5);
            std.mem.copy(u8, sub, line[5..]);
            result.subject = sub;
        } else {
            try contents.appendSlice(line);
            try contents.appendSlice("\n");
        }
    }

    var str_contents = try allocator.alloc.alloc(u8, contents.items.len);
    std.mem.copy(u8, str_contents, contents.items);

    result.contents = str_contents;

    return result;
}

pub fn init() void {
    emails = std.ArrayList(Email).init(allocator.alloc);
}

pub fn deinit() void {
    for (emails.items) |email| {
        allocator.alloc.free(email.from);
        allocator.alloc.free(email.subject);
        allocator.alloc.free(email.contents);
    }

    emails.deinit();
}

pub fn load() !void {
    var path = fm.getContentDir();
    defer allocator.alloc.free(path);

    var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

    var file = try d.openFile("content/emails.eme", .{});

    var lenbuffer: []u8 = try allocator.alloc.alloc(u8, 4);
    var bytebuffer: []u8 = try allocator.alloc.alloc(u8, 1);
    defer allocator.alloc.free(bytebuffer);

    defer allocator.alloc.free(lenbuffer);
    _ = try file.read(lenbuffer);
    var count = @bitCast(u32, lenbuffer[0..4].*);
    try emails.resize(count);

    for (range(count), 0..) |_, idx| {
        _ = try file.read(bytebuffer);
        emails.items[idx].id = bytebuffer[0];
        _ = try file.read(bytebuffer);
        emails.items[idx].box = bytebuffer[0];

        _ = try file.read(lenbuffer);
        var fromsize = @bitCast(u32, lenbuffer[0..4].*);
        var frombuffer: []u8 = try allocator.alloc.alloc(u8, fromsize);
        _ = try file.read(frombuffer);
        emails.items[idx].from = frombuffer;

        _ = try file.read(lenbuffer);
        var subsize = @bitCast(u32, lenbuffer[0..4].*);
        var subbuffer: []u8 = try allocator.alloc.alloc(u8, subsize);
        _ = try file.read(subbuffer);
        emails.items[idx].subject = subbuffer;

        _ = try file.read(lenbuffer);
        var contentsize = @bitCast(u32, lenbuffer[0..4].*);
        var contentbuffer: []u8 = try allocator.alloc.alloc(u8, contentsize);
        _ = try file.read(contentbuffer);
        emails.items[idx].contents = contentbuffer;
    }
}

pub const Email = struct {
    from: []const u8,
    subject: []const u8,
    contents: []const u8,
    solved: bool = false,
    selected: bool = false,
    box: u8 = 0,
    id: u8 = 0,
};
