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

pub fn format(self: Operation, writer: anytype) !void {
    if (self.string) |string| {
        return writer.print("{s} \"{f}\"", .{ @tagName(self.code), std.ascii.hexEscape(string, .lower) });
    } else if (self.value) |value| {
        return writer.print("{s} {}", .{ @tagName(self.code), value });
    } else {
        return writer.print("{s}", .{@tagName(self.code)});
    }
}
