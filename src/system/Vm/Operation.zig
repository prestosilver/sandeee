const std = @import("std");

const Operation = @This();

pub const Code = enum(u8) {
    nop,
    sys,

    push,
    add,
    sub,
    copy,

    jmp,
    jz,
    jnz,
    jmpf,

    mul,
    div,

    land,
    lor,
    lnot,
    eq,

    getb,

    ret,
    call,

    neg,
    xor,
    disc,
    asign,
    dup,

    less,
    greater,

    cat,
    mod,
    create,
    size,
    len,

    sin,
    cos,
    random,
    seed,
    zero,
    mem,
    disc_at,

    _,
};

code: Code,
string: ?[]const u8 = null,
value: ?u64 = null,

pub fn format(self: Operation, writer: anytype) !void {
    const code = std.enums.tagName(Code, self.code) orelse "UnknownOp";

    if (self.string) |string| {
        return writer.print("{s} \"{f}\"", .{ code, std.ascii.hexEscape(string, .lower) });
    } else if (self.value) |value| {
        return writer.print("{s} {}", .{ code, value });
    } else {
        return writer.print("{s}", .{code});
    }
}
