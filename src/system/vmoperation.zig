const std = @import("std");

const Operation = @This();

pub const Code = enum(u8) {
    Nop,
    Sys,

    Push,
    Add,
    Sub,
    Copy,

    Jmp,
    Jz,
    Jnz,
    Jmpf,

    Mul,
    Div,

    And,
    Or,
    Not,
    Eq,

    Getb,

    Ret,
    Call,

    Neg,
    Xor,
    Disc,
    Asign,
    Dup,

    Less,
    Greater,

    Cat,
    Mod,
    Create,
    Size,
    Len,

    Sin,
    Cos,
    Random,
    Seed,
    Zero,
    Mem,
    DiscN,

    Last,
    _,
};

code: Code,
string: ?[]const u8 = null,
value: ?u64 = null,

pub fn format(
    self: Operation,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (self.string) |string| {
        return std.fmt.format(writer, "{s} \"{s}\"", .{ @tagName(self.code), string });
    } else if (self.value) |value| {
        return std.fmt.format(writer, "{s} {}", .{ @tagName(self.code), value });
    } else {
        return std.fmt.format(writer, "{s}", .{@tagName(self.code)});
    }
}
