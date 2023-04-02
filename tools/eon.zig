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
    op: Token,
    b: []Expression,

    fn toAsm(self: *Expression, map: *VarMap, idx: *i32) ![]const u8 {
        var result: []u8 = try allocator.alloc(u8, 0);
        if (self.op.kind == .TOKEN_OPEN_PAREN) {
            var start = idx.*;
            for (self.a) |*item| {
                var adds = try item.toAsm(map, idx);
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
            }

            idx.* = start + 1;

            var adds = try std.fmt.allocPrint(allocator, "    call {s}\n", .{self.op.value});
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
            return result;
        }
        for (self.a) |*item| {
            var adds = try item.toAsm(map, idx);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }
        for (self.b) |*item| {
            var adds = try item.toAsm(map, idx);
            var start_res = result.len;
            result = try allocator.realloc(result, result.len + adds.len);
            std.mem.copy(u8, result[start_res..], adds);
        }
        switch (self.op.kind) {
            .TOKEN_INT_LIT => {
                idx.* += 1;
                var adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.value});
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                return result;
            },
            .TOKEN_STRING_LIT => {
                idx.* += 1;
                var adds = try std.fmt.allocPrint(allocator, "    push {s}\n", .{self.op.value});
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
            .TOKEN_ADD => {
                idx.* -= 1;
                var adds = "    add\n";
                var start_res = result.len;
                result = try allocator.realloc(result, result.len + adds.len);
                std.mem.copy(u8, result[start_res..], adds);
                return result;
            },
            else => return error.UnknownToken,
            //TODO MOAR
        }
    }
};

const Statement = struct {
    kind: StatementKind,
    data: *void,

    fn toAsm(self: *Statement, map: *VarMap, idx: *i32) []const u8 {
        _ = map;
        _ = idx;

        switch (self.kind) {
            .STMT_INVALID => {
                return try std.fmt.allocPrint(allocator, "    nop\n", .{});
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
};

const Program = struct {
    funcs: []FunctionDecl,
};

const Var = struct {
    name: []const u8,
    idx: u32,
};

const VarMap = struct {
    max: i32,
    vars: []const Var,
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
            if (char != '\\') {
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
                var toks = try lex_file(stmt[8..]);
                defer toks.deinit();

                try result.appendSlice(toks.items);
            }
        }

        if (code.len != 0 and (std.mem.indexOf(u8, " \"{}();,\t\n-~![]", charStr) != null or std.mem.indexOf(u8, " \"{}();,\t\n-~![]", code[code.len - 1 ..]) != null)) {
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
            } else if (code[0] == '"' and code[code.len - 1] == '"') {
                try result.append(.{
                    .kind = .TOKEN_STRING_LIT,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else {
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
                            .kind = .TOKEN_IDENT,
                            .value = code,
                        });
                    }
                }
                code = try allocator.alloc(u8, 0);
            }
        }

        if (prev == '/' and char == '/') {
            var stmt_buff: [512]u8 = undefined;
            _ = try reader.readUntilDelimiterOrEof(&stmt_buff, '\n');
        }

        if ((std.mem.indexOf(u8, "\t\r\n ", charStr) == null or code.len != 0 and code[0] == '"')) {
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

pub fn compileEon(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    allocator = alloc;

    var tokens = try lex_file(in);

    for (tokens.items) |tok|
        std.log.info("toks: {s}", .{tok.value});

    var exp: Expression = .{
        .a = &[_]Expression{},
        .op = .{
            .kind = .TOKEN_OPEN_PAREN,
            .value = "lolol",
        },
        .b = &[_]Expression{},
    };

    var result = std.ArrayList(u8).init(alloc);

    var idx: i32 = 0;

    var adds = try exp.toAsm(&VarMap{ .max = 0, .vars = try alloc.alloc(Var, 0) }, &idx);
    try result.appendSlice(adds);

    return result;
}
