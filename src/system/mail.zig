const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");

pub var emails: std.ArrayList(Email) = undefined;

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub fn checkLine(line: []const u8, start: []const u8) bool {
    if (line.len < start.len) return false;

    for (start) |char, idx|
        if (char != line[idx]) return false;

    return true;
}

pub fn append(e: Email) void {
    emails.append(e) catch {};
}

pub fn toStr() std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(allocator.alloc);

    var len = @bitCast([4]u8, @intCast(u32, emails.items.len));
    result.appendSlice(&len) catch {};
    for (emails.items) |email| {
        result.append(email.id) catch {};
        result.append(email.box) catch {};
        len = @bitCast([4]u8, @intCast(u32, email.from.len));
        result.appendSlice(&len) catch {};
        result.appendSlice(email.from) catch {};
        len = @bitCast([4]u8, @intCast(u32, email.subject.len));
        result.appendSlice(&len) catch {};
        result.appendSlice(email.subject) catch {};
        len = @bitCast([4]u8, @intCast(u32, email.contents.len));
        result.appendSlice(&len) catch {};
        result.appendSlice(email.contents) catch {};
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
            contents.appendSlice(line) catch {};
            contents.appendSlice("\n") catch {};
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
    var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

    var file = try d.openFile("content/emails.eme", .{});

    var lenbuffer: []u8 = allocator.alloc.alloc(u8, 4) catch undefined;
    var bytebuffer: []u8 = allocator.alloc.alloc(u8, 1) catch undefined;
    defer allocator.alloc.free(bytebuffer);

    defer allocator.alloc.free(lenbuffer);
    _ = file.read(lenbuffer) catch 0;
    var count = @bitCast(u32, lenbuffer[0..4].*);
    try emails.resize(count);

    for (range(count)) |_, idx| {
        _ = file.read(bytebuffer) catch 0;
        emails.items[idx].id = bytebuffer[0];
        _ = file.read(bytebuffer) catch 0;
        emails.items[idx].box = bytebuffer[0];

        _ = file.read(lenbuffer) catch 0;
        var fromsize = @bitCast(u32, lenbuffer[0..4].*);
        var frombuffer: []u8 = allocator.alloc.alloc(u8, fromsize) catch undefined;
        _ = file.read(frombuffer) catch 0;
        emails.items[idx].from = frombuffer;

        _ = file.read(lenbuffer) catch 0;
        var subsize = @bitCast(u32, lenbuffer[0..4].*);
        var subbuffer: []u8 = allocator.alloc.alloc(u8, subsize) catch undefined;
        _ = file.read(subbuffer) catch 0;
        emails.items[idx].subject = subbuffer;

        _ = file.read(lenbuffer) catch 0;
        var contentsize = @bitCast(u32, lenbuffer[0..4].*);
        var contentbuffer: []u8 = allocator.alloc.alloc(u8, contentsize) catch undefined;
        _ = file.read(contentbuffer) catch 0;
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
