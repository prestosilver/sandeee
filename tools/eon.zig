const std = @import("std");
const assembler = @import("asm.zig");
var allocator: std.mem.Allocator = undefined;

const TokenKind = enum {
    TOKEN_OPEN_BRACE,
    TOKEN_CLOSE_BRACE,
    TOKEN_OPEN_PAREN,
    TOKEN_CLOSE_PAREN,
    TOKEN_SEMI_COLON,
    TOKEN_KEYWORD_VAR,
    TOKEN_KEYWORD_FN,
    TOKEN_KEYWORD_RETURN,
    TOKEN_KEYWORD_ASM,
    TOKEN_KEYWORD_IF,
    TOKEN_KEYWORD_ELSE,

    TOKEN_KEYWORD_FOR,
    TOKEN_KEYWORD_WHILE,
    TOKEN_KEYWORD_DO,
    TOKEN_KEYWORD_BREAK,
    TOKEN_KEYWORD_CONTINUE,
    TOKEN_KEYWORD_NEW,

    TOKEN_KEYWORD_FNSET,

    TOKEN_IDENT,
    TOKEN_INT_LIT,
    TOKEN_STRING_LIT,
    TOKEN_NEG,

    TOKEN_BIT_NOT,
    TOKEN_NOT,

    TOKEN_SUBREL,
    TOKEN_ADDREL,
    TOKEN_MULREL,
    TOKEN_DIVREL,
    TOKEN_MODREL,
    TOKEN_CATREL,

    TOKEN_ADD,
    TOKEN_MUL,
    TOKEN_DIV,
    TOKEN_MOD,
    TOKEN_CAT,
    TOKEN_AT,

    TOKEN_AND,
    TOKEN_OR,
    TOKEN_EQ,
    TOKEN_NEQ,
    TOKEN_LT,
    TOKEN_LTE,
    TOKEN_GT,
    TOKEN_GTE,

    TOKEN_COMMA,

    TOKEN_ASSIGN,
    TOKEN_HEAP_ASSIGN,
    TOKEN_HEAP_READ,

    TOKEN_EOF,
};

const StatementKind = enum {
    STMT_INVALID,
    STMT_RETURN,
    STMT_ASM,
    STMT_DECLARE,
    STMT_EXP,
    STMT_COND,
    STMT_BREAK,
    STMT_CONTINUE,
    STMT_FOR,
    STMT_FOR_DECL,
    STMT_WHILE,
    STMT_DO,
    STMT_CALL,
};

const Token = struct {
    kind: TokenKind,
    value: []const u8,
};

const Expression = struct {
    a: []Expression,
    op: ?*Token,
    b: []Expression,

    fn toAsm(self: *Expression, map: *VarMap, heap: *const std.ArrayList([]const u8), idx: *usize) ![]const u8 {
        var result: []u8 = try allocator.alloc(u8, 0);
        if (self.op != null and self.op.?.kind == .TOKEN_OPEN_PAREN) {
            const start = idx.*;
            for (self.a) |*item| {
                const adds = try item.toAsm(map, heap, idx);
                const start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
            }

            idx.* = start + 1;

            var adds: []const u8 = undefined;
            if (std.mem.eql(u8, self.op.?.value, "dup")) {
                adds = try std.fmt.allocPrint(allocator, "    dup 0\n    disc 1\n", .{});
            } else {
                if (self.op.?.value[0] == '_') {
                    adds = try std.fmt.allocPrint(allocator, "    call \"{s}\"\n", .{self.op.?.value[1..]});
                } else {
                    adds = try std.fmt.allocPrint(allocator, "    call {s}\n", .{self.op.?.value});
                }
            }
            defer allocator.free(adds);
            const start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            @memcpy(result[start_res..], adds);
            return result;
        }

        for (self.a, 0..) |_, index| {
            const adds = try self.a[index].toAsm(map, heap, idx);
            defer allocator.free(adds);
            const start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            @memcpy(result[start_res..], adds);
        }
        for (self.b, 0..) |_, index| {
            const adds = try self.b[index].toAsm(map, heap, idx);
            defer allocator.free(adds);
            const start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            @memcpy(result[start_res..], adds);
        }
        if (self.op != null) {
            switch (self.op.?.kind) {
                .TOKEN_INT_LIT => {
                    idx.* += 1;
                    const adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.?.value});
                    defer allocator.free(adds);
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_STRING_LIT => {
                    idx.* += 1;
                    const adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.?.value});
                    defer allocator.free(adds);
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_SUBREL => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    sub\n" ++
                        "    disc 1\n" ++
                        "    set\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_NEG => {
                    if (self.a.len != 0) {
                        idx.* -= 1;
                        const adds = "    sub\n";
                        const start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                        return result;
                    }
                    const adds = "    neg\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_BIT_NOT => {
                    const adds = "    not\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_NOT => {
                    const adds = "    push 1\n    xor\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_AT => {
                    const adds = "    getb\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_HEAP_READ => {
                    const adds = "    sys 15\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_ADDREL => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    add\n" ++
                        "    disc 1\n" ++
                        "    set\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_ADD => {
                    idx.* -= 1;
                    const adds = "    add\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_MUL => {
                    idx.* -= 1;
                    const adds = "    mul\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_DIV => {
                    idx.* -= 1;
                    const adds = "    div\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_MOD => {
                    idx.* -= 1;
                    const adds = "    mod\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_AND => {
                    idx.* -= 1;
                    const adds = "    and\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_OR => {
                    idx.* -= 1;
                    const adds = "    or\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_CATREL => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    cat\n" ++
                        "    disc 1\n" ++
                        "    set\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_CAT => {
                    idx.* -= 1;
                    const adds = "    cat\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_HEAP_ASSIGN => {
                    idx.* -= 1;
                    const adds = "    sys 16\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_ASSIGN => {
                    idx.* -= 1;
                    const adds = "    set\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_GT => {
                    idx.* -= 1;
                    const adds = "    gt\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_LT => {
                    idx.* -= 1;
                    const adds = "    lt\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_NEQ => {
                    idx.* -= 1;
                    const adds = "    eq\n    not\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_EQ => {
                    idx.* -= 1;
                    const adds = "    eq\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_KEYWORD_NEW => {
                    const adds = "    create\n    zero\n";
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    return result;
                },
                .TOKEN_IDENT => {
                    for (map.vars) |mapvar| {
                        if (std.mem.eql(u8, mapvar.name, self.op.?.value)) {
                            const adds = try std.fmt.allocPrint(allocator, "    copy {}\n", .{idx.* - 1 - mapvar.idx});
                            const start_res = result.len;
                            result = try allocator.realloc(result, result.len + adds.len);
                            @memcpy(result[start_res..], adds);
                            idx.* += 1;

                            return result;
                        }
                    }
                    for (heap.items, 0..) |entry, i| {
                        if (std.mem.eql(u8, entry, self.op.?.value)) {
                            const adds = try std.fmt.allocPrint(allocator, "    push {}\n", .{i});
                            const start_res = result.len;
                            result = try allocator.realloc(result, result.len + adds.len);
                            @memcpy(result[start_res..], adds);
                            idx.* += 1;

                            return result;
                        }
                    }

                    std.log.info("udefined: {s}", .{self.op.?.value});
                    return error.UnknownIdent;
                },
                .TOKEN_CLOSE_PAREN => {
                    return result;
                },
                else => {
                    std.log.info("{}", .{self.op.?.kind});
                    return error.UnknownToken;
                },
                //TODO MOAR
            }
        }
        return result;
    }
};

var block_id: usize = 0;

const Statement = struct {
    kind: StatementKind,
    name: ?[]const u8,
    exprs: ?[]Expression,
    blks: ?[][]Statement,

    fn toAsm(self: *Statement, map: *VarMap, heap: *const std.ArrayList([]const u8), idx: *usize) ![]const u8 {
        switch (self.kind) {
            .STMT_INVALID => {
                return try std.fmt.allocPrint(allocator, "    nop\n", .{});
            },
            .STMT_DECLARE => {
                var result = try allocator.alloc(u8, 0);

                if (self.exprs != null) {
                    const adds = try self.exprs.?[0].toAsm(map, heap, idx);
                    defer allocator.free(adds);
                    const start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                } else {
                    result = try std.fmt.allocPrint(allocator, "    push 0\n", .{});
                    idx.* += 1;
                }
                map.vars = try allocator.realloc(map.vars, map.vars.len + 1);
                map.vars[map.vars.len - 1] = .{
                    .name = self.name.?,
                    .idx = idx.* - 1,
                };
                return result;
            },
            .STMT_COND => {
                const start = idx.*;
                const block = block_id;
                const map_start = try allocator.dupe(Var, map.vars);
                block_id += 1;

                var result = try allocator.alloc(u8, 0);

                var adds = try self.exprs.?[0].toAsm(map, heap, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jz block_{}_alt\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    allocator.free(adds);
                    adds = try stmt.toAsm(map, heap, idx);
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                }

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;
                        idx.* -= 1;
                    }

                    if (count > 0) {
                        allocator.free(adds);
                        adds = try std.fmt.allocPrint(allocator, "    push 0\n    ndisc {}\n", .{count});
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                    }
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jmp block_{}_end\nblock_{}_alt:\n", .{ block, block });
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                if (self.blks.?.len > 1) {
                    for (self.blks.?[1]) |*stmt| {
                        allocator.free(adds);
                        adds = try stmt.toAsm(map, heap, idx);
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                    }

                    {
                        var count: usize = 0;

                        for (start..idx.*) |_| {
                            count += 1;
                            idx.* -= 1;
                        }

                        if (count > 0) {
                            allocator.free(adds);
                            adds = try std.fmt.allocPrint(allocator, "    push 0\n    ndisc {}\n", .{count});
                            start_res = result.len;
                            result = try allocator.realloc(result, result.len + adds.len);
                            @memcpy(result[start_res..], adds);
                        }
                    }
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "block_{}_end:\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                map.vars = map_start;

                return result;
            },
            .STMT_RETURN => {
                var result = try allocator.alloc(u8, 0);

                var adds = try self.exprs.?[0].toAsm(map, heap, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                idx.* -= 1;

                {
                    var count: usize = 0;

                    for (0..idx.*) |_| {
                        count += 1;
                    }

                    if (count > 0) {
                        allocator.free(adds);
                        adds = try std.fmt.allocPrint(allocator, "    push 1\n    ndisc {}\n", .{count});
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                    }
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    ret\n", .{});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
                return result;
            },
            .STMT_WHILE => {
                const start = idx.*;
                const block = block_id;
                const map_start = try allocator.dupe(Var, map.vars);
                block_id += 1;

                var result = try allocator.alloc(u8, 0);

                var adds: []const u8 = try std.fmt.allocPrint(allocator, "block_{}_loop:\n", .{block});
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try self.exprs.?[0].toAsm(map, heap, idx);
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jz block_{}_end\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    allocator.free(adds);
                    adds = try stmt.toAsm(map, heap, idx);
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jmp block_{}_loop\nblock_{}_end:\n", .{ block, block });
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;
                        idx.* -= 1;
                    }

                    if (count > 0) {
                        allocator.free(adds);
                        adds = try std.fmt.allocPrint(allocator, "    push 0\n    ndisc {}\n", .{count});
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                    }
                }

                map.vars = map_start;

                return result;
            },
            .STMT_FOR => {
                const start = idx.*;
                const map_start = try allocator.dupe(Var, map.vars);
                const block = block_id;
                block_id += 1;

                var result = try allocator.alloc(u8, 0);

                var adds = try self.blks.?[0][0].toAsm(map, heap, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "block_{}_loop:\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try self.exprs.?[0].toAsm(map, heap, idx);
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jz block_{}_end\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
                idx.* -= 1;

                for (self.blks.?[1]) |*stmt| {
                    allocator.free(adds);
                    adds = try stmt.toAsm(map, heap, idx);
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                }

                allocator.free(adds);
                adds = try self.exprs.?[1].toAsm(map, heap, idx);
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    disc 0\n    jmp block_{}_loop\nblock_{}_end:\n", .{ block, block });
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);
                idx.* -= 1;

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;

                        idx.* -= 1;
                    }

                    if (count > 0) {
                        allocator.free(adds);
                        adds = try std.fmt.allocPrint(allocator, "    push 0\n    ndisc {}\n", .{count});
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        @memcpy(result[start_res..], adds);
                    }
                }

                map.vars = map_start;

                return result;
            },
            .STMT_ASM => {
                const result = std.fmt.allocPrint(allocator, "    {s}\n", .{self.name.?[1 .. self.name.?.len - 1]});
                return result;
            },
            .STMT_EXP => {
                var result = try allocator.alloc(u8, 0);
                const start = idx.*;

                var adds = try self.exprs.?[0].toAsm(map, heap, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                @memcpy(result[start_res..], adds);

                for (start..idx.*) |_| {
                    allocator.free(adds);
                    adds = try std.fmt.allocPrint(allocator, "    disc 0\n", .{});
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    @memcpy(result[start_res..], adds);
                    idx.* -= 1;
                }

                return result;
            },
            else => {
                std.log.info("{}", .{self.kind});
                return error.NotImplemented;
            },
        }
    }
};

const FunctionParam = struct {
    name: []const u8,
};

const FunctionDecl = struct {
    params: []FunctionParam,
    ret: []const u8,
    ident: []const u8,
    stmts: []Statement,

    fn toAsm(self: *FunctionDecl, heap: *const std.ArrayList([]const u8), lib: bool) ![]const u8 {
        const prefix = if (lib) "_" else "";
        var result = try std.fmt.allocPrint(allocator, "{s}{s}:\n", .{ prefix, self.ident });
        var map = VarMap{ .vars = try allocator.alloc(Var, self.params.len) };
        for (self.params, 0..) |param, idx| {
            map.vars[idx] = .{
                .name = param.name,
                .idx = idx,
            };
        }

        var idx = self.params.len;

        for (self.stmts) |*stmt| {
            const adds = try stmt.toAsm(&map, heap, &idx);
            defer allocator.free(adds);
            const start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            @memcpy(result[start_res..], adds);
        }

        return result;
    }
};

const Program = struct {
    funcs: []FunctionDecl,
    heap: std.ArrayList([]const u8),

    fn toAsm(self: *Program, lib: bool) ![]const u8 {
        var result =
            if (!lib) try std.fmt.allocPrint(allocator, "    push {}\n    sys 14\n    call main\n    sys 1\n", .{self.heap.items.len}) else try std.fmt.allocPrint(allocator, "", .{});

        for (self.funcs) |*func| {
            const adds = try func.toAsm(&self.heap, lib);
            defer allocator.free(adds);
            const start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            @memcpy(result[start_res..], adds);
        }
        return result;
    }
};

const Var = struct {
    name: []const u8,
    idx: usize,
};

const VarMap = struct {
    vars: []Var,
};

pub fn lexFile(b: *std.Build, in: []const u8) !std.ArrayList(Token) {
    var f = try std.fs.openFileAbsolute(in, .{});
    defer f.close();
    var reader = f.reader();

    var result = std.ArrayList(Token).init(allocator);
    var buff: [1]u8 = undefined;
    var prev: u8 = '\n';
    var code = try allocator.alloc(u8, 0);
    while (true) {
        const size = try reader.read(&buff);
        if (size == 0) break;

        const char = buff[0];
        const char_string: []const u8 = &buff;

        if (prev == '\\') {
            if (char == '"') {
                code[code.len - 1] = char;
                prev = 'n';
            } else {
                code = try allocator.realloc(code, code.len + 1);
                code[code.len - 1] = char;
                prev = 'n';
            }

            continue;
        }

        if (prev == '\n' and char == '#') {
            var stmt_buff: [256]u8 = undefined;
            var stmt = (try reader.readUntilDelimiterOrEof(&stmt_buff, '\n')).?;

            if (std.mem.eql(u8, stmt[0..8], "include ")) {
                const target = b.path("content").path(b, stmt[10 .. stmt.len - 1]);

                var toks = try lexFile(b, target.getPath(b));
                defer toks.deinit();

                _ = toks.pop();

                try result.appendSlice(toks.items);
            }
            code = try allocator.alloc(u8, 0);

            continue;
        }

        if (code.len != 0 and (std.mem.indexOf(u8, " @${}();,\t\n~![]", char_string) != null or std.mem.indexOf(u8, " $@{}();,\t\n~![]", code[code.len - 1 ..]) != null)) {
            if (std.mem.eql(u8, code, "{")) {
                try result.append(.{
                    .kind = .TOKEN_OPEN_BRACE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "}")) {
                try result.append(.{
                    .kind = .TOKEN_CLOSE_BRACE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "(")) {
                try result.append(.{
                    .kind = .TOKEN_OPEN_PAREN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, ")")) {
                try result.append(.{
                    .kind = .TOKEN_CLOSE_PAREN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, ";")) {
                try result.append(.{
                    .kind = .TOKEN_SEMI_COLON,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "var")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_VAR,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "fnset")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_FNSET,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "fn")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_FN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "return")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_RETURN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "asm")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_ASM,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "if")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_IF,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "else")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_ELSE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "for")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_FOR,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "while")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_WHILE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "do")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_DO,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "break")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_BREAK,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "continue")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_CONTINUE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "new")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_NEW,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "&&")) {
                try result.append(.{
                    .kind = .TOKEN_AND,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "||")) {
                try result.append(.{
                    .kind = .TOKEN_OR,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "+=")) {
                try result.append(.{
                    .kind = .TOKEN_ADDREL,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "+")) {
                try result.append(.{
                    .kind = .TOKEN_ADD,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "-=")) {
                try result.append(.{
                    .kind = .TOKEN_SUBREL,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "-")) {
                try result.append(.{
                    .kind = .TOKEN_NEG,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "*")) {
                try result.append(.{
                    .kind = .TOKEN_MUL,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "/")) {
                try result.append(.{
                    .kind = .TOKEN_DIV,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "%")) {
                try result.append(.{
                    .kind = .TOKEN_MOD,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "<")) {
                try result.append(.{
                    .kind = .TOKEN_LT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, ">")) {
                try result.append(.{
                    .kind = .TOKEN_GT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, ",")) {
                try result.append(.{
                    .kind = .TOKEN_COMMA,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "&")) {
                try result.append(.{
                    .kind = .TOKEN_CAT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "&=")) {
                try result.append(.{
                    .kind = .TOKEN_CATREL,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "@")) {
                try result.append(.{
                    .kind = .TOKEN_AT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "$")) {
                try result.append(.{
                    .kind = .TOKEN_HEAP_READ,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, ":=")) {
                try result.append(.{
                    .kind = .TOKEN_HEAP_ASSIGN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "=")) {
                try result.append(.{
                    .kind = .TOKEN_ASSIGN,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "==")) {
                try result.append(.{
                    .kind = .TOKEN_EQ,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "!=")) {
                try result.append(.{
                    .kind = .TOKEN_NEQ,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (code.len > 1 and code.len != 0 and code[0] == '"' and code[code.len - 1] == '"') {
                try result.append(.{
                    .kind = .TOKEN_STRING_LIT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (!std.mem.eql(u8, code, "\"")) {
                if (code[0] == '-' and code.len != 1) {
                    try result.append(.{
                        .kind = .TOKEN_NEG,
                        .value = code[0..1],
                    });
                    code = code[1..];
                }

                var is_ident = true;

                for (code) |ch| {
                    if (!std.ascii.isAlphabetic(ch) and ch != '_') {
                        is_ident = false;
                        break;
                    }
                }
                if (is_ident) {
                    try result.append(.{
                        .kind = .TOKEN_IDENT,
                        .value = code,
                    });
                    code = try allocator.alloc(u8, 0);
                } else {
                    var is_digit = true;

                    for (code) |ch| {
                        if (!std.ascii.isDigit(ch)) {
                            is_digit = false;
                            break;
                        }
                    }
                    if (is_digit) {
                        try result.append(.{
                            .kind = .TOKEN_INT_LIT,
                            .value = code,
                        });
                        code = try allocator.alloc(u8, 0);
                    }
                    //else {
                    //    std.log.info("{s}", .{code});
                    //    return error.UnknownToken;
                    //}
                }
            }
        }

        if (prev == '/' and char == '/') {
            code = try allocator.alloc(u8, 0);

            var stmt_buff: [512]u8 = undefined;
            _ = try reader.readUntilDelimiterOrEof(&stmt_buff, '\n');
        } else if ((std.mem.indexOf(u8, "\t\r\n ", char_string) == null or (code.len != 0 and code[0] == '"'))) {
            code = try allocator.realloc(code, code.len + 1);
            code[code.len - 1] = char;
        }

        prev = char;
    }

    try result.append(.{
        .kind = .TOKEN_EOF,
        .value = "EOF",
    });

    return result;
}

const EMPTY_EXPR = [_]Expression{};

pub fn parseFactor(tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) !Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    if (tokens[idx.*].kind == .TOKEN_OPEN_PAREN) {
        idx.* += 1;
        var a = try allocator.alloc(Expression, 1);
        a[0] = try parseExpression(tokens, heap, idx);

        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;

        result = .{
            .a = a,
            .op = &tokens[idx.* - 1],
            .b = &EMPTY_EXPR,
        };

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_INT_LIT or
        tokens[idx.*].kind == .TOKEN_STRING_LIT or
        tokens[idx.*].kind == .TOKEN_IDENT)
    {
        if (tokens[idx.* + 1].kind == .TOKEN_MUL or
            tokens[idx.* + 1].kind == .TOKEN_DIV or
            tokens[idx.* + 1].kind == .TOKEN_MOD)
        {
            const op = &tokens[idx.* + 1];
            var a = try allocator.alloc(Expression, 1);
            a[0] = .{
                .a = &EMPTY_EXPR,
                .op = &tokens[idx.*],
                .b = &EMPTY_EXPR,
            };

            idx.* += 2;
            var b = try allocator.alloc(Expression, 1);
            b[0] = try parseFactor(tokens, heap, idx);
            result = .{
                .a = a,
                .op = op,
                .b = b,
            };
            return result;
        } else if (tokens[idx.* + 1].kind == .TOKEN_OPEN_PAREN) {
            if (tokens[idx.*].kind != .TOKEN_IDENT) return error.NoIdent;
            var ident = &tokens[idx.*];
            idx.* += 2;
            var b = try allocator.alloc(Expression, 0);
            while (parseExpression(tokens, heap, idx) catch null) |expr| {
                b = try allocator.realloc(b, b.len + 1);
                b[b.len - 1] = expr;
                if (tokens[idx.*].kind != .TOKEN_COMMA) break;
                idx.* += 1;
            }
            if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
            idx.* += 1;

            ident.kind = .TOKEN_OPEN_PAREN;

            result = .{
                .a = b,
                .op = ident,
                .b = &EMPTY_EXPR,
            };
            return result;
        } else {
            result = .{
                .a = &EMPTY_EXPR,
                .op = &tokens[idx.*],
                .b = &EMPTY_EXPR,
            };
            idx.* += 1;
            return result;
        }
    } else if (tokens[idx.*].kind == .TOKEN_NEG) {
        const ident = &tokens[idx.*];
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseFactor(tokens, heap, idx);

        result = .{
            .a = &EMPTY_EXPR,
            .op = ident,
            .b = b,
        };
        return result;
    } else if (tokens[idx.*].kind == .TOKEN_AT or
        tokens[idx.*].kind == .TOKEN_HEAP_READ or
        tokens[idx.*].kind == .TOKEN_KEYWORD_NEW)
    {
        const ident = &tokens[idx.*];
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseFactor(tokens, heap, idx);

        result = .{
            .a = &EMPTY_EXPR,
            .op = ident,
            .b = b,
        };
        return result;
    }
    return error.NoFactor;
}

pub fn parseSum(tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) !Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseFactor(tokens, heap, idx);

    if (tokens[idx.*].kind == .TOKEN_ADD or
        tokens[idx.*].kind == .TOKEN_CAT or
        tokens[idx.*].kind == .TOKEN_NEG)
    {
        const op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, heap, idx);
        result = .{
            .a = a,
            .op = op,
            .b = b,
        };
    } else {
        result = .{
            .a = a,
            .op = null,
            .b = &EMPTY_EXPR,
        };
    }
    return result;
}

pub fn parseExpression(tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) anyerror!Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseSum(tokens, heap, idx);

    if (tokens[idx.*].kind == .TOKEN_AND or
        tokens[idx.*].kind == .TOKEN_OR or
        tokens[idx.*].kind == .TOKEN_LT or
        tokens[idx.*].kind == .TOKEN_GT or
        tokens[idx.*].kind == .TOKEN_EQ or
        tokens[idx.*].kind == .TOKEN_NEQ or
        tokens[idx.*].kind == .TOKEN_ASSIGN or
        tokens[idx.*].kind == .TOKEN_HEAP_ASSIGN or
        tokens[idx.*].kind == .TOKEN_ADDREL or
        tokens[idx.*].kind == .TOKEN_CATREL or
        tokens[idx.*].kind == .TOKEN_SUBREL)
    {
        const op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, heap, idx);
        result = .{
            .a = a,
            .op = op,
            .b = b,
        };
    } else {
        result = .{
            .a = a,
            .op = null,
            .b = &EMPTY_EXPR,
        };
    }

    return result;
}

pub fn parseStatement(tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) !Statement {
    var result: Statement = .{
        .kind = .STMT_INVALID,
        .name = null,
        .exprs = null,
        .blks = null,
    };
    if (tokens[idx.*].kind == .TOKEN_KEYWORD_VAR) {
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_IDENT) return error.ExpectedIdent;

        result = .{
            .kind = .STMT_DECLARE,
            .name = tokens[idx.*].value,
            .exprs = null,
            .blks = null,
        };

        idx.* += 1;

        if (tokens[idx.*].kind == .TOKEN_ASSIGN) {
            idx.* += 1;
            var b = try allocator.alloc(Expression, 1);
            b[0] = try parseExpression(tokens, heap, idx);

            result.exprs = b;
        }
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_RETURN) {
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, heap, idx);

        result = .{
            .kind = .STMT_RETURN,
            .name = null,
            .exprs = b,
            .blks = null,
        };
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_ASM) {
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_STRING_LIT) return error.ExpectedSC;

        result = .{
            .kind = .STMT_ASM,
            .name = tokens[idx.*].value,
            .exprs = null,
            .blks = null,
        };
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_FOR) {
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_OPEN_PAREN) return error.ExpectedParen;
        idx.* += 1;
        var exprs = try allocator.alloc(Expression, 2);
        var blks = try allocator.alloc([]Statement, 2);
        blks[0] = try allocator.alloc(Statement, 1);
        blks[0][0] = try parseStatement(tokens, heap, idx);
        exprs[0] = try parseExpression(tokens, heap, idx);
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.Semi;
        idx.* += 1;
        exprs[1] = try parseExpression(tokens, heap, idx);
        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;
        blks[1] = try parseBlock(tokens, heap, idx);

        result = .{
            .kind = .STMT_FOR,
            .name = null,
            .exprs = exprs,
            .blks = blks,
        };

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_WHILE) {
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_OPEN_PAREN) return error.ExpectedParen;
        idx.* += 1;
        var exprs = try allocator.alloc(Expression, 1);
        exprs[0] = try parseExpression(tokens, heap, idx);
        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;
        var blks = try allocator.alloc([]Statement, 1);
        blks[0] = try parseBlock(tokens, heap, idx);

        result = .{
            .kind = .STMT_WHILE,
            .name = null,
            .exprs = exprs,
            .blks = blks,
        };

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_IF) {
        idx.* += 1;
        if (tokens[idx.*].kind != .TOKEN_OPEN_PAREN) return error.ExpectedParen;
        idx.* += 1;

        var s = try allocator.alloc(Expression, 1);
        s[0] = try parseExpression(tokens, heap, idx);

        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;

        var b = try allocator.alloc([]Statement, 1);
        b[0] = try parseBlock(tokens, heap, idx);

        if (tokens[idx.*].kind == .TOKEN_KEYWORD_ELSE) {
            idx.* += 1;
            b = try allocator.realloc(b, 2);
            b[1] = try parseBlock(tokens, heap, idx);
        }

        result = .{
            .kind = .STMT_COND,
            .name = null,
            .exprs = s,
            .blks = b,
        };

        return result;
    } else {
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, heap, idx);

        result = .{
            .kind = .STMT_EXP,
            .name = null,
            .exprs = b,
            .blks = null,
        };

        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.ExpectedSC;
        idx.* += 1;

        return result;
    }

    return error.NoStmt;
}

pub fn parseBlock(tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) anyerror![]Statement {
    var result: []Statement = undefined;

    if (tokens[idx.*].kind != .TOKEN_OPEN_BRACE) {
        result = try allocator.alloc(Statement, 1);
        result[0] = try parseStatement(tokens, heap, idx);

        return result;
    }
    idx.* += 1;
    result = try allocator.alloc(Statement, 0);

    while (parseStatement(tokens, heap, idx) catch null) |stmt| {
        result = try allocator.realloc(result, result.len + 1);
        result[result.len - 1] = stmt;
    }

    if (tokens[idx.*].kind != .TOKEN_CLOSE_BRACE) return error.NoClose;
    idx.* += 1;

    return result;
}

pub fn parseFunctionParam(tokens: []Token, idx: *usize) !FunctionParam {
    var result: FunctionParam = .{
        .name = "",
    };

    if (tokens[idx.*].kind != .TOKEN_IDENT) return error.ExpectedValue;
    result.name = tokens[idx.*].value;
    idx.* += 1;

    return result;
}

pub fn parseFunctionDecl(fnPrefix: *[]const u8, tokens: []Token, heap: *std.ArrayList([]const u8), idx: *usize) !FunctionDecl {
    var result: FunctionDecl = undefined;
    if (tokens[idx.*].kind != .TOKEN_KEYWORD_FN) return error.ExpectedType;
    idx.* += 1;
    if (tokens[idx.*].kind != .TOKEN_IDENT) return error.ExpectedIdent;
    result.ident = try std.fmt.allocPrint(allocator, "{s}{s}", .{ fnPrefix.*, tokens[idx.*].value });
    idx.* += 1;
    if (tokens[idx.*].kind != .TOKEN_OPEN_PAREN) return error.ExpectedParen;
    idx.* += 1;
    if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) {
        result.params = try allocator.alloc(FunctionParam, 0);
        while (parseFunctionParam(tokens, idx) catch null) |param| {
            result.params = try allocator.realloc(result.params, result.params.len + 1);
            result.params[result.params.len - 1] = param;
            if (tokens[idx.*].kind != .TOKEN_COMMA) break;
            idx.* += 1;
        }
        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;
    } else {
        result.params = &[_]FunctionParam{};
        idx.* += 1;
    }

    result.stmts = try parseBlock(tokens, heap, idx);

    return result;
}

pub fn parseProgram(fn_prefix: *[]const u8, tokens: []Token) !Program {
    var result: Program = undefined;
    var idx: usize = 0;
    result = .{
        .funcs = try allocator.alloc(FunctionDecl, 0),
        .heap = std.ArrayList([]const u8).init(allocator),
    };

    while (true) {
        if (parseFunctionDecl(fn_prefix, tokens, &result.heap, &idx) catch null) |func| {
            result.funcs = try allocator.realloc(result.funcs, result.funcs.len + 1);
            result.funcs[result.funcs.len - 1] = func;
        } else if (tokens[idx].kind == .TOKEN_KEYWORD_VAR) {
            idx += 1;
            if (tokens[idx].kind != .TOKEN_IDENT) return error.ExpectedIdent;
            try result.heap.append(tokens[idx].value);
            idx += 1;

            if (tokens[idx].kind != .TOKEN_SEMI_COLON) return error.ExpectedIdent;
            idx += 1;
        } else if (tokens[idx].kind == .TOKEN_KEYWORD_FNSET) {
            idx += 1;
            if (tokens[idx].kind != .TOKEN_IDENT) return error.ExpectedIdent;
            const old_prefix = fn_prefix.*;
            defer allocator.free(old_prefix);
            fn_prefix.* = try std.fmt.allocPrint(allocator, "{s}.", .{tokens[idx].value});
            idx += 1;
            if (tokens[idx].kind != .TOKEN_OPEN_BRACE) return error.ExpectedIdent;
            idx += 1;
        } else if (tokens[idx].kind == .TOKEN_CLOSE_BRACE) {
            idx += 1;
            const dotidx = if (std.mem.lastIndexOf(u8, fn_prefix.*[0 .. fn_prefix.*.len - 1], ".")) |ind| ind + 1 else 0;

            fn_prefix.* = try allocator.dupe(u8, fn_prefix.*[0..dotidx]);
        } else {
            break;
        }
    }

    if (fn_prefix.len != 0) return error.POOPIE;

    if (tokens[idx].kind != .TOKEN_EOF) {
        for (tokens[idx..]) |tok|
            std.log.info("toks: {} '{s}'", .{ @intFromEnum(tok.kind), tok.value });

        return error.ExpectedEOF;
    }

    idx += 1;

    return result;
}

pub fn compileEon(
    b: *std.Build,
    paths: []const std.Build.LazyPath,
    output: std.Build.LazyPath,
) !void {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var fn_prefix: []const u8 = "";

    allocator = b.allocator;

    var tokens = try lexFile(b, in.getPath(b));
    defer tokens.deinit();

    var prog = try parseProgram(&fn_prefix, tokens.items);

    const path = output.getPath(b);

    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    const writer = file.writer();

    const adds = try prog.toAsm(false);
    try writer.writeAll(adds);
}

pub fn compileEonLib(
    b: *std.Build,
    paths: []const std.Build.LazyPath,
    output: std.Build.LazyPath,
) !void {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var fn_prefix: []const u8 = "";

    allocator = b.allocator;

    var tokens = try lexFile(b, in.getPath(b));
    defer tokens.deinit();

    var prog = try parseProgram(&fn_prefix, tokens.items);

    const path = output.getPath(b);

    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    const writer = file.writer();

    const adds = try prog.toAsm(true);
    try writer.writeAll(adds);
}
