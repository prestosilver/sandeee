const std = @import("std");
const assembler = @import("asm.zig");
var allocator: std.mem.Allocator = undefined;

const TokenKind = enum {
    TOKEN_OPEN_BRACE,
    TOKEN_CLOSE_BRACE,
    TOKEN_OPEN_PAREN,
    TOKEN_CLOSE_PAREN,
    TOKEN_SEMI_COLON,
    TOKEN_KEYWORD_VALUE,
    TOKEN_KEYWORD_VOID,
    TOKEN_KEYWORD_RETURN,
    TOKEN_KEYWORD_ASM,
    TOKEN_KEYWORD_IF,
    TOKEN_KEYWORD_ELSE,

    TOKEN_KEYWORD_FOR,
    TOKEN_KEYWORD_WHILE,
    TOKEN_KEYWORD_DO,
    TOKEN_KEYWORD_BREAK,
    TOKEN_KEYWORD_CONTINUE,

    TOKEN_IDENT,
    TOKEN_INT_LIT,
    TOKEN_STRING_LIT,
    TOKEN_NEG,

    TOKEN_BIT_NOT,
    TOKEN_NOT,

    TOKEN_ADD,
    TOKEN_MUL,
    TOKEN_DIV,
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

    fn toAsm(self: *Expression, map: *VarMap, idx: *usize) ![]const u8 {
        var result: []u8 = try allocator.alloc(u8, 0);
        if (self.op != null and self.op.?.kind == .TOKEN_OPEN_PAREN) {
            var start = idx.*;
            for (self.a) |*item| {
                var adds = try item.toAsm(map, idx);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
            }

            idx.* = start + 1;

            var adds = try std.fmt.allocPrint(allocator, "    call {s}\n", .{self.op.?.value});
            defer allocator.free(adds);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
            return result;
        }

        for (self.a, 0..) |_, index| {
            var adds = try self.a[index].toAsm(map, idx);
            defer allocator.free(adds);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }
        for (self.b, 0..) |_, index| {
            var adds = try self.b[index].toAsm(map, idx);
            defer allocator.free(adds);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }
        if (self.op != null) {
            switch (self.op.?.kind) {
                .TOKEN_INT_LIT => {
                    idx.* += 1;
                    var adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.?.value});
                    defer allocator.free(adds);
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_STRING_LIT => {
                    idx.* += 1;
                    var adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.?.value});
                    defer allocator.free(adds);
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_NEG => {
                    if (self.a.len != 0) {
                        idx.* -= 1;
                        var adds = "    sub\n";
                        var start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        std.mem.copy(u8, result[start_res..], adds);
                        return result;
                    }
                    var adds = "    neg\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_BIT_NOT => {
                    var adds = "    not\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_NOT => {
                    var adds = "    push 1\n    xor\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_AT => {
                    var adds = "    getb\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_ADD => {
                    idx.* -= 1;
                    var adds = "    add\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_AND => {
                    idx.* -= 1;
                    var adds = "    and\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_OR => {
                    idx.* -= 1;
                    var adds = "    or\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_CAT => {
                    idx.* -= 1;
                    var adds = "    cat\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_ASSIGN => {
                    idx.* -= 1;
                    var adds = "    set\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_GT => {
                    idx.* -= 1;
                    var adds = "    gt\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_LT => {
                    idx.* -= 1;
                    var adds = "    lt\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_NEQ => {
                    idx.* -= 1;
                    var adds = "    eq\n    not\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_EQ => {
                    idx.* -= 1;
                    var adds = "    eq\n";
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    return result;
                },
                .TOKEN_IDENT => {
                    for (0..map.max) |i| {
                        if (std.mem.eql(u8, map.vars[i].name, self.op.?.value)) {
                            var adds = try std.fmt.allocPrint(allocator, "    copy {}\n", .{idx.* - 1 - map.vars[i].idx});
                            var start_res = result.len;
                            result = try allocator.realloc(result, result.len + adds.len);
                            std.mem.copy(u8, result[start_res..], adds);
                            idx.* += 1;

                            return result;
                        }
                    }
                    std.log.info("{s}", .{self.op.?.value});
                    return error.UnknownIdent;
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

    fn toAsm(self: *Statement, map: *VarMap, idx: *usize) ![]const u8 {
        switch (self.kind) {
            .STMT_INVALID => {
                return try std.fmt.allocPrint(allocator, "    nop\n", .{});
            },
            .STMT_DECLARE => {
                var result = try allocator.alloc(u8, 0);

                if (self.exprs != null) {
                    var adds = try self.exprs.?[0].toAsm(map, idx);
                    defer allocator.free(adds);
                    var start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                } else {
                    result = try std.fmt.allocPrint(allocator, "    push 0\n", .{});
                    idx.* += 1;
                }
                map.max += 1;
                map.vars = try allocator.realloc(map.vars, map.vars.len + 1);
                map.vars[map.vars.len - 1] = .{
                    .name = self.name.?,
                    .idx = idx.* - 1,
                };
                return result;
            },
            .STMT_COND => {
                var start = idx.*;
                var map_start = map.max;
                var block = block_id;
                block_id += 1;

                var result = try allocator.alloc(u8, 0);

                var adds = try self.exprs.?[0].toAsm(map, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jz block_{}_alt\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    allocator.free(adds);
                    adds = try stmt.toAsm(map, idx);
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                }

                for (start..idx.*) |_| {
                    allocator.free(adds);
                    adds = try std.fmt.allocPrint(allocator, "    disc 1\n", .{});
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    idx.* -= 1;
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jmp block_{}_end\nblock_{}_alt:\n", .{ block, block });
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                map.max = map_start;

                if (self.blks.?.len > 1) {
                    for (self.blks.?[1]) |*stmt| {
                        allocator.free(adds);
                        adds = try stmt.toAsm(map, idx);
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        std.mem.copy(u8, result[start_res..], adds);
                    }

                    for (start..idx.*) |_| {
                        allocator.free(adds);
                        adds = try std.fmt.allocPrint(allocator, "    disc 1\n", .{});
                        start_res = result.len;
                        result = try allocator.realloc(result, result.len + adds.len);
                        std.mem.copy(u8, result[start_res..], adds);
                        idx.* -= 1;
                    }
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "block_{}_end:\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                return result;
            },
            .STMT_RETURN => {
                var result = try allocator.alloc(u8, 0);

                var adds = try self.exprs.?[0].toAsm(map, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                idx.* -= 1;

                for (0..idx.*) |_| {
                    allocator.free(adds);
                    adds = try std.fmt.allocPrint(allocator, "    disc 1\n", .{});
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                }

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    dup 0\n    disc 1\n    ret\n", .{});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                return result;
            },
            .STMT_FOR => {
                var start = idx.*;
                var map_start = map.max;
                var block = block_id;
                block_id += 1;

                var result = try allocator.alloc(u8, 0);

                var adds = try self.exprs.?[0].toAsm(map, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    disc 0\nblock_{}_loop:\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                idx.* -= 1;

                allocator.free(adds);
                adds = try self.exprs.?[1].toAsm(map, idx);
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    jz block_{}_end\n", .{block});
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    allocator.free(adds);
                    adds = try stmt.toAsm(map, idx);
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                }

                allocator.free(adds);
                adds = try self.exprs.?[2].toAsm(map, idx);
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                allocator.free(adds);
                adds = try std.fmt.allocPrint(allocator, "    disc 0\n    jmp block_{}_loop\nblock_{}_end:\n", .{ block, block });
                start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                idx.* -= 1;

                for (start..idx.*) |_| {
                    allocator.free(adds);
                    adds = try std.fmt.allocPrint(allocator, "    disc 1\n", .{});
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
                    idx.* -= 1;
                }

                map.max = map_start;

                return result;
            },
            .STMT_ASM => {
                var result = std.fmt.allocPrint(allocator, "    {s}\n", .{self.name.?[1 .. self.name.?.len - 1]});
                return result;
            },
            .STMT_EXP => {
                var result = try allocator.alloc(u8, 0);
                var start = idx.*;

                var adds = try self.exprs.?[0].toAsm(map, idx);
                defer allocator.free(adds);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);

                for (start..idx.*) |_| {
                    allocator.free(adds);
                    adds = try std.fmt.allocPrint(allocator, "    disc 0\n", .{});
                    start_res = result.len;
                    result = try allocator.realloc(result, result.len + adds.len);
                    std.mem.copy(u8, result[start_res..], adds);
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
    kind: []const u8,
    name: []const u8,
};

const FunctionDecl = struct {
    params: []FunctionParam,
    ret: []const u8,
    ident: []const u8,
    stmts: []Statement,

    fn toAsm(self: *FunctionDecl) ![]const u8 {
        var result = try std.fmt.allocPrint(allocator, "{s}:\n", .{self.ident});
        var map = VarMap{ .max = self.params.len, .vars = try allocator.alloc(Var, self.params.len) };
        for (self.params, 0..) |param, idx| {
            map.vars[idx] = .{
                .name = param.name,
                .idx = idx,
            };
        }

        var idx = self.params.len;

        for (self.stmts) |*stmt| {
            var adds = try stmt.toAsm(&map, &idx);
            defer allocator.free(adds);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }

        return result;
    }
};

const Program = struct {
    funcs: []FunctionDecl,

    fn toAsm(self: *Program) ![]const u8 {
        var result = try std.fmt.allocPrint(allocator, "    call main\n    sys 1\n", .{});

        for (self.funcs) |*func| {
            var adds = try func.toAsm();
            defer allocator.free(adds);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }
        return result;
    }
};

const Var = struct {
    name: []const u8,
    idx: usize,
};

const VarMap = struct {
    max: usize,
    vars: []Var,
};

pub fn lex_file(in: []const u8) !std.ArrayList(Token) {
    var f = try std.fs.cwd().openFile(in, .{});
    defer f.close();
    var reader = f.reader();

    var result = std.ArrayList(Token).init(allocator);
    var buff: [1]u8 = undefined;
    var prev: u8 = '\n';
    var code = try allocator.alloc(u8, 0);
    while (true) {
        var size = try reader.read(&buff);
        if (size == 0) break;

        var char = buff[0];
        var charStr: []const u8 = &buff;

        if (prev == '\\') {
            if (char == '"') {
                code[code.len - 1] = char;
                prev = 'n';
            } else if (char != '\\') {
                code[code.len - 1] = char;
                prev = char;
            } else {
                prev = 'n';
            }

            continue;
        }

        if (prev == '\n' and char == '#') {
            var stmt_buff: [256]u8 = undefined;
            var stmt = (try reader.readUntilDelimiterOrEof(&stmt_buff, '\n')).?;

            if (std.mem.eql(u8, stmt[0..8], "include ")) {
                var toks = try lex_file(stmt[9 .. stmt.len - 1]);
                defer toks.deinit();

                _ = toks.pop();

                try result.appendSlice(toks.items);
            }
            code = try allocator.alloc(u8, 0);

            continue;
        }

        if (code.len != 0 and (std.mem.indexOf(u8, " @{}();,\t\n-~![]", charStr) != null or std.mem.indexOf(u8, " @{}();,\t\n-~![]", code[code.len - 1 ..]) != null)) {
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
            } else if (std.mem.eql(u8, code, "value")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_VALUE,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (std.mem.eql(u8, code, "void")) {
                try result.append(.{
                    .kind = .TOKEN_KEYWORD_VOID,
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
            } else if (std.mem.eql(u8, code, "+")) {
                try result.append(.{
                    .kind = .TOKEN_ADD,
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
            } else if (std.mem.eql(u8, code, "@")) {
                try result.append(.{
                    .kind = .TOKEN_AT,
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
                var isIdent = true;

                for (code) |ch| {
                    if (!std.ascii.isAlphabetic(ch)) {
                        isIdent = false;
                        break;
                    }
                }
                if (isIdent) {
                    try result.append(.{
                        .kind = .TOKEN_IDENT,
                        .value = code,
                    });
                    code = try allocator.alloc(u8, 0);
                } else {
                    var isDigit = true;

                    for (code) |ch| {
                        if (!std.ascii.isDigit(ch)) {
                            isDigit = false;
                            break;
                        }
                    }
                    if (isDigit) {
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
        } else if ((std.mem.indexOf(u8, "\t\r\n ", charStr) == null or (code.len != 0 and code[0] == '"'))) {
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

const emptyExpr = [_]Expression{};

pub fn parseFactor(tokens: []Token, idx: *usize) !Expression {
    var result: Expression = .{
        .a = &emptyExpr,
        .op = null,
        .b = &emptyExpr,
    };

    if (tokens[idx.*].kind == .TOKEN_OPEN_PAREN) {
        idx.* += 1;
        var a = try allocator.alloc(Expression, 1);
        a[0] = try parseFactor(tokens, idx);

        idx.* += 1;
        result = .{
            .a = a,
            .op = &tokens[idx.* - 1],
            .b = &emptyExpr,
        };

        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_INT_LIT or
        tokens[idx.*].kind == .TOKEN_STRING_LIT or
        tokens[idx.*].kind == .TOKEN_IDENT)
    {
        if (tokens[idx.* + 1].kind == .TOKEN_MUL or
            tokens[idx.* + 1].kind == .TOKEN_DIV)
        {
            var op = &tokens[idx.* + 1];
            var a = try allocator.alloc(Expression, 1);
            a[0] = .{
                .a = &emptyExpr,
                .op = &tokens[idx.* + 1],
                .b = &emptyExpr,
            };

            idx.* += 2;
            var b = try allocator.alloc(Expression, 1);
            a[0] = try parseFactor(tokens, idx);
            result = .{
                .a = a,
                .op = op,
                .b = b,
            };
            return result;
        } else if (tokens[idx.* + 1].kind == .TOKEN_OPEN_PAREN) {
            var ident = &tokens[idx.*];
            idx.* += 2;
            var b = try allocator.alloc(Expression, 0);
            while (parseExpression(tokens, idx) catch null) |expr| {
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
                .b = &emptyExpr,
            };
            return result;
        } else {
            result = .{
                .a = &emptyExpr,
                .op = &tokens[idx.*],
                .b = &emptyExpr,
            };
            idx.* += 1;
            return result;
        }
    } else if (tokens[idx.*].kind == .TOKEN_AT) {
        var ident = &tokens[idx.*];
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseFactor(tokens, idx);

        result = .{
            .a = &emptyExpr,
            .op = ident,
            .b = b,
        };
        return result;
    }
    return error.NoFactor;
}

pub fn parseSum(tokens: []Token, idx: *usize) !Expression {
    var result: Expression = .{
        .a = &emptyExpr,
        .op = null,
        .b = &emptyExpr,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseFactor(tokens, idx);

    if (tokens[idx.*].kind == .TOKEN_ADD or
        tokens[idx.*].kind == .TOKEN_CAT or
        tokens[idx.*].kind == .TOKEN_ASSIGN or
        tokens[idx.*].kind == .TOKEN_NEG)
    {
        var op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, idx);
        result = .{
            .a = a,
            .op = op,
            .b = b,
        };
    } else {
        result = .{
            .a = a,
            .op = null,
            .b = &emptyExpr,
        };
    }
    return result;
}

pub fn parseExpression(tokens: []Token, idx: *usize) anyerror!Expression {
    var result: Expression = .{
        .a = &emptyExpr,
        .op = null,
        .b = &emptyExpr,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseSum(tokens, idx);

    if (tokens[idx.*].kind == .TOKEN_AND or
        tokens[idx.*].kind == .TOKEN_OR or
        tokens[idx.*].kind == .TOKEN_LT or
        tokens[idx.*].kind == .TOKEN_GT or
        tokens[idx.*].kind == .TOKEN_EQ or
        tokens[idx.*].kind == .TOKEN_NEQ)
    {
        var op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, idx);
        result = .{
            .a = a,
            .op = op,
            .b = b,
        };
    } else {
        result = .{
            .a = a,
            .op = null,
            .b = &emptyExpr,
        };
    }

    return result;
}

pub fn parseStatement(tokens: []Token, idx: *usize) !Statement {
    var result: Statement = .{
        .kind = .STMT_INVALID,
        .name = null,
        .exprs = null,
        .blks = null,
    };
    if (tokens[idx.*].kind == .TOKEN_KEYWORD_VALUE) {
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
            b[0] = try parseExpression(tokens, idx);

            result.exprs = b;
        }
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .TOKEN_KEYWORD_RETURN) {
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(tokens, idx);

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
        var exprs = try allocator.alloc(Expression, 3);
        exprs[0] = try parseExpression(tokens, idx);
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.Semi;
        idx.* += 1;
        exprs[1] = try parseExpression(tokens, idx);
        if (tokens[idx.*].kind != .TOKEN_SEMI_COLON) return error.Semi;
        idx.* += 1;
        exprs[2] = try parseExpression(tokens, idx);
        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;
        var blks = try allocator.alloc([]Statement, 1);
        blks[0] = try parseBlock(tokens, idx);

        result = .{
            .kind = .STMT_FOR,
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
        s[0] = try parseExpression(tokens, idx);

        if (tokens[idx.*].kind != .TOKEN_CLOSE_PAREN) return error.NoClose;
        idx.* += 1;

        var b = try allocator.alloc([]Statement, 1);
        b[0] = try parseBlock(tokens, idx);

        if (tokens[idx.*].kind == .TOKEN_KEYWORD_ELSE) {
            idx.* += 1;
            b = try allocator.realloc(b, 2);
            b[1] = try parseBlock(tokens, idx);
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
        b[0] = try parseExpression(tokens, idx);

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

pub fn parseBlock(tokens: []Token, idx: *usize) anyerror![]Statement {
    var result: []Statement = undefined;

    if (tokens[idx.*].kind != .TOKEN_OPEN_BRACE) {
        result = try allocator.alloc(Statement, 1);
        result[0] = try parseStatement(tokens, idx);

        return result;
    }
    idx.* += 1;
    result = try allocator.alloc(Statement, 0);

    while (parseStatement(tokens, idx) catch null) |stmt| {
        result = try allocator.realloc(result, result.len + 1);
        result[result.len - 1] = stmt;
    }

    if (tokens[idx.*].kind != .TOKEN_CLOSE_BRACE) return error.NoClose;
    idx.* += 1;

    return result;
}

pub fn parseFunctionParam(tokens: []Token, idx: *usize) !FunctionParam {
    var result: FunctionParam = .{
        .kind = "",
        .name = "",
    };

    if (tokens[idx.*].kind != .TOKEN_KEYWORD_VALUE) return error.ExpectedValue;
    result.kind = tokens[idx.*].value;
    idx.* += 1;
    if (tokens[idx.*].kind != .TOKEN_IDENT) return error.ExpectedValue;
    result.name = tokens[idx.*].value;
    idx.* += 1;

    return result;
}

pub fn parseFunctionDecl(tokens: []Token, idx: *usize) !FunctionDecl {
    var result: FunctionDecl = undefined;
    if (tokens[idx.*].kind != .TOKEN_KEYWORD_VALUE and
        tokens[idx.*].kind != .TOKEN_KEYWORD_VOID) return error.ExpectedType;
    result.ret = tokens[idx.*].value;
    idx.* += 1;
    if (tokens[idx.*].kind != .TOKEN_IDENT) return error.ExpectedIdent;
    result.ident = tokens[idx.*].value;
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

    result.stmts = try parseBlock(tokens, idx);

    return result;
}

pub fn parseProgram(tokens: []Token) !Program {
    var result: Program = undefined;
    var idx: usize = 0;
    result = .{
        .funcs = try allocator.alloc(FunctionDecl, 0),
    };

    while (parseFunctionDecl(tokens, &idx) catch null) |func| {
        result.funcs = try allocator.realloc(result.funcs, result.funcs.len + 1);
        result.funcs[result.funcs.len - 1] = func;
    }

    if (tokens[idx].kind != .TOKEN_EOF) {
        for (tokens[idx..]) |tok|
            std.log.info("toks: {} '{s}'", .{ @enumToInt(tok.kind), tok.value });

        return error.ExpectedEOF;
    }

    idx += 1;

    return result;
}

pub fn compileEon(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    allocator = alloc;

    var tokens = try lex_file(in);
    defer tokens.deinit();

    //for (tokens.items) |tok|
    //    std.log.info("toks: {} '{s}'", .{ @enumToInt(tok.kind), tok.value });

    var prog = try parseProgram(tokens.items);

    var result = std.ArrayList(u8).init(alloc);

    var adds = try prog.toAsm();
    try result.appendSlice(adds);

    return result;
}
