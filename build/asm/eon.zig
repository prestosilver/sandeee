const std = @import("std");

var lib_path: []const u8 = undefined;

const TokenKind = enum {};

const Token = struct {
    const Kind = enum {
        open_brace,
        close_brace,
        open_paren,
        close_paren,
        semi_colon,
        keyword_var,
        keyword_fn,
        keyword_return,
        keyword_asm,
        keyword_if,
        keyword_else,

        keyword_for,
        keyword_while,
        keyword_do,
        keyword_break,
        keyword_continue,
        keyword_new,

        keyword_fnset,

        ident,
        int_literal,
        string_literal,

        bit_not,
        not,
        at,

        sub_equals,
        add_equals,
        mul_equals,
        div_equals,
        mod_equals,
        cat_equals,

        sub,
        add,
        mul,
        div,
        mod,
        cat,

        and_op,
        or_op,
        eq,
        not_eq,
        lt,
        lt_eq,
        gt,
        gt_eq,

        comma,

        assign,
        heap_assign,
        heap_read,

        eof,
    };

    const KIND_NAMES: std.StaticStringMap(Kind) = .initComptime(.{
        .{ "{", .open_brace },
        .{ "}", .close_brace },
        .{ "(", .open_paren },
        .{ ")", .close_paren },
        .{ ";", .semi_colon },

        .{ "var", .keyword_var },
        .{ "fn", .keyword_fn },
        .{ "return", .keyword_return },
        .{ "asm", .keyword_asm },
        .{ "if", .keyword_if },
        .{ "else", .keyword_else },

        .{ "for", .keyword_for },
        .{ "while", .keyword_while },
        .{ "do", .keyword_do },
        .{ "break", .keyword_break },
        .{ "continue", .keyword_continue },
        .{ "new", .keyword_new },

        .{ "fnset", .keyword_fnset },

        .{ "~", .bit_not },
        //.{ "!", .not },
        .{ "@", .at },

        .{ "-=", .sub_equals },
        .{ "+=", .add_equals },
        .{ "*=", .mul_equals },
        .{ "/=", .div_equals },
        .{ "%=", .mod_equals },
        .{ "&=", .cat_equals },

        .{ "-", .sub },
        .{ "+", .add },
        .{ "*", .mul },
        .{ "/", .div },
        .{ "%", .mod },
        .{ "&", .cat },

        .{ "&&", .and_op },
        .{ "||", .or_op },
        .{ "==", .eq },
        .{ "!=", .not_eq },

        .{ "<", .lt },
        .{ "<=", .lt_eq },
        .{ ">", .gt },
        .{ ">=", .gt_eq },

        .{ ",", .comma },

        .{ "=", .assign },

        .{ ":=", .heap_assign },
        .{ "$", .heap_read },
    });

    kind: Kind,
    value: []const u8,
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

const Expression = struct {
    a: []Expression,
    op: ?*Token,
    b: []Expression,

    fn toAsm(self: *Expression, allocator: std.mem.Allocator, map: *VarMap, heap: *const std.array_list.Managed([]const u8), idx: *usize) ![]const u8 {
        var result: std.array_list.Managed(u8) = .init(allocator);
        defer result.deinit();

        if (self.op != null and self.op.?.kind == .open_paren) {
            const start = idx.*;
            for (self.a) |*item| {
                const adds = try item.toAsm(allocator, map, heap, idx);
                try result.appendSlice(adds);
            }

            idx.* = start + 1;

            if (std.mem.eql(u8, self.op.?.value, "dup")) {
                try result.print("    dup 0\n    disc 1\n", .{});
            } else {
                if (self.op.?.value[0] == '_') {
                    try result.print("    call \"{s}\"\n", .{self.op.?.value[1..]});
                } else {
                    try result.print("    call {s}\n", .{self.op.?.value});
                }
            }

            return result.toOwnedSlice();
        }

        for (self.a, 0..) |_, index| {
            const adds = try self.a[index].toAsm(allocator, map, heap, idx);
            defer allocator.free(adds);
            try result.appendSlice(adds);
        }

        for (self.b, 0..) |_, index| {
            const adds = try self.b[index].toAsm(allocator, map, heap, idx);
            defer allocator.free(adds);
            try result.appendSlice(adds);
        }

        if (self.op != null) {
            switch (self.op.?.kind) {
                .int_literal => {
                    idx.* += 1;

                    try result.print("    push {s}\n", .{self.op.?.value});

                    return result.toOwnedSlice();
                },
                .string_literal => {
                    idx.* += 1;

                    try result.print("    push {s}\n", .{self.op.?.value});

                    return result.toOwnedSlice();
                },
                .sub_equals => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    sub\n" ++
                        "    disc 1\n" ++
                        "    set\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .sub => {
                    if (self.a.len != 0) {
                        idx.* -= 1;
                        const adds = "    sub\n";

                        try result.appendSlice(adds);
                        return result.toOwnedSlice();
                    }
                    const adds = "    neg\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .bit_not => {
                    const adds = "    not\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .not => {
                    const adds = "    push 1\n    xor\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .at => {
                    const adds = "    getb\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .heap_read => {
                    const adds = "    sys 15\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .add_equals => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    add\n" ++
                        "    disc 1\n" ++
                        "    set\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .add => {
                    idx.* -= 1;
                    const adds = "    add\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .mul => {
                    idx.* -= 1;
                    const adds = "    mul\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .div => {
                    idx.* -= 1;
                    const adds = "    div\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .mod => {
                    idx.* -= 1;
                    const adds = "    mod\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .and_op => {
                    idx.* -= 1;
                    const adds = "    and\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .or_op => {
                    idx.* -= 1;
                    const adds = "    or\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .cat_equals => {
                    idx.* -= 1;
                    const adds = "    copy 1\n" ++
                        "    copy 1\n" ++
                        "    cat\n" ++
                        "    disc 1\n" ++
                        "    set\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .cat => {
                    idx.* -= 1;
                    const adds = "    cat\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .heap_assign => {
                    idx.* -= 1;
                    const adds = "    sys 16\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .assign => {
                    idx.* -= 1;
                    const adds = "    set\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .gt => {
                    idx.* -= 1;
                    const adds = "    gt\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .lt => {
                    idx.* -= 1;
                    const adds = "    lt\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .not_eq => {
                    idx.* -= 1;
                    const adds = "    eq\n    not\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .eq => {
                    idx.* -= 1;
                    const adds = "    eq\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .keyword_new => {
                    const adds = "    create\n    zero\n";

                    try result.appendSlice(adds);
                    return result.toOwnedSlice();
                },
                .ident => {
                    for (map.vars) |mapvar| {
                        if (std.mem.eql(u8, mapvar.name, self.op.?.value)) {
                            try result.print("    copy {}\n", .{idx.* - 1 - mapvar.idx});

                            idx.* += 1;

                            return result.toOwnedSlice();
                        }
                    }
                    for (heap.items, 0..) |entry, i| {
                        if (std.mem.eql(u8, entry, self.op.?.value)) {
                            try result.print("    push {}\n", .{i});

                            idx.* += 1;

                            return result.toOwnedSlice();
                        }
                    }

                    std.log.info("udefined: {s}", .{self.op.?.value});
                    return error.UnknownIdent;
                },
                .close_paren => {
                    return result.toOwnedSlice();
                },
                else => {
                    std.log.info("{}", .{self.op.?.kind});
                    return error.UnknownToken;
                },
                //TODO MOAR
            }
        }
        return result.toOwnedSlice();
    }
};

var block_id: usize = 0;

const Statement = struct {
    kind: StatementKind,
    name: ?[]const u8,
    exprs: ?[]Expression,
    blks: ?[][]Statement,

    fn toAsm(self: *Statement, allocator: std.mem.Allocator, map: *VarMap, heap: *const std.array_list.Managed([]const u8), idx: *usize) ![]const u8 {
        var result: std.array_list.Managed(u8) = .init(allocator);
        defer result.deinit();

        switch (self.kind) {
            .STMT_INVALID => {
                try result.print("    nop\n", .{});

                return result.toOwnedSlice();
            },
            .STMT_DECLARE => {
                if (self.exprs != null) {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                } else {
                    try result.print("    push 0\n", .{});

                    idx.* += 1;
                }

                map.vars = try allocator.realloc(map.vars, map.vars.len + 1);
                map.vars[map.vars.len - 1] = .{
                    .name = self.name.?,
                    .idx = idx.* - 1,
                };
                return result.toOwnedSlice();
            },
            .STMT_COND => {
                const start = idx.*;
                const block = block_id;
                const map_start = try allocator.dupe(Var, map.vars);
                block_id += 1;

                {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);
                    try result.appendSlice(adds);
                }

                try result.print("    jz block_{}_alt\n", .{block});

                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    const adds = try stmt.toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;
                        idx.* -= 1;
                    }

                    if (count > 0)
                        try result.print("    push 0\n    ndisc {}\n", .{count});
                }

                try result.print("    jmp block_{}_end\nblock_{}_alt:\n", .{ block, block });

                if (self.blks.?.len > 1) {
                    for (self.blks.?[1]) |*stmt| {
                        const adds = try stmt.toAsm(allocator, map, heap, idx);
                        defer allocator.free(adds);

                        try result.appendSlice(adds);
                    }

                    {
                        var count: usize = 0;

                        for (start..idx.*) |_| {
                            count += 1;
                            idx.* -= 1;
                        }

                        if (count > 0) {
                            try result.print("    push 0\n    ndisc {}\n", .{count});
                        }
                    }
                }

                try result.print("block_{}_end:\n", .{block});

                map.vars = map_start;

                return result.toOwnedSlice();
            },
            .STMT_RETURN => {
                {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                idx.* -= 1;

                {
                    var count: usize = 0;

                    for (0..idx.*) |_| {
                        count += 1;
                    }

                    if (count > 0) {
                        try result.print("    push 1\n    ndisc {}\n", .{count});
                    }
                }

                try result.print("    ret\n", .{});

                return result.toOwnedSlice();
            },
            .STMT_WHILE => {
                const start = idx.*;
                const block = block_id;
                const map_start = try allocator.dupe(Var, map.vars);
                block_id += 1;

                try result.print("block_{}_loop:\n", .{block});

                {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                try result.print("    jz block_{}_end\n", .{block});
                idx.* -= 1;

                for (self.blks.?[0]) |*stmt| {
                    const adds = try stmt.toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                try result.print("    jmp block_{}_loop\nblock_{}_end:\n", .{ block, block });

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;
                        idx.* -= 1;
                    }

                    if (count > 0) {
                        try result.print("    push 0\n    ndisc {}\n", .{count});
                    }
                }

                map.vars = map_start;

                return result.toOwnedSlice();
            },
            .STMT_FOR => {
                const start = idx.*;
                const map_start = try allocator.dupe(Var, map.vars);
                const block = block_id;
                block_id += 1;

                {
                    const adds = try self.blks.?[0][0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                try result.print("block_{}_loop:\n", .{block});

                {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);
                    try result.appendSlice(adds);
                }

                try result.print("    jz block_{}_end\n", .{block});

                idx.* -= 1;

                for (self.blks.?[1]) |*stmt| {
                    const adds = try stmt.toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                {
                    const adds = try self.exprs.?[1].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                try result.print("    disc 0\n    jmp block_{}_loop\nblock_{}_end:\n", .{ block, block });

                idx.* -= 1;

                {
                    var count: usize = 0;

                    while (start != idx.*) {
                        count += 1;

                        idx.* -= 1;
                    }

                    if (count > 0)
                        try result.print("    push 0\n    ndisc {}\n", .{count});
                }

                map.vars = map_start;

                return result.toOwnedSlice();
            },
            .STMT_ASM => {
                try result.print("    {s}\n", .{self.name.?[1 .. self.name.?.len - 1]});

                return result.toOwnedSlice();
            },
            .STMT_EXP => {
                const start = idx.*;

                {
                    const adds = try self.exprs.?[0].toAsm(allocator, map, heap, idx);
                    defer allocator.free(adds);

                    try result.appendSlice(adds);
                }

                for (start..idx.*) |_| {
                    try result.print("    disc 0\n", .{});

                    idx.* -= 1;
                }

                return result.toOwnedSlice();
            },
            else => {
                std.log.info("{}", .{self.kind});
                return error.Unimplemented;
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

    fn toAsm(self: *FunctionDecl, allocator: std.mem.Allocator, heap: *const std.array_list.Managed([]const u8), lib: bool) ![]const u8 {
        var result: std.array_list.Managed(u8) = .init(allocator);
        defer result.deinit();

        const prefix = if (lib) "_" else "";

        try result.print("{s}{s}:\n", .{ prefix, self.ident });

        var map = VarMap{
            .vars = try allocator.alloc(Var, self.params.len),
        };
        for (self.params, 0..) |param, idx| {
            map.vars[idx] = .{
                .name = param.name,
                .idx = idx,
            };
        }

        var idx = self.params.len;
        for (self.stmts) |*stmt| {
            const adds = try stmt.toAsm(allocator, &map, heap, &idx);
            defer allocator.free(adds);

            try result.appendSlice(adds);
        }

        return result.toOwnedSlice();
    }
};

const Program = struct {
    funcs: []FunctionDecl,
    heap: std.array_list.Managed([]const u8),

    fn toAsm(self: *Program, allocator: std.mem.Allocator, lib: bool) ![]const u8 {
        var result: std.array_list.Managed(u8) = .init(allocator);
        defer result.deinit();

        if (!lib)
            try result.print(
                \\    push {}
                \\    sys 14
                \\    call main
                \\    sys 1
                \\
            , .{self.heap.items.len});

        for (self.funcs) |*func| {
            const adds = try func.toAsm(allocator, &self.heap, lib);
            defer allocator.free(adds);

            try result.appendSlice(adds);
        }

        return result.toOwnedSlice();
    }
};

const Var = struct {
    name: []const u8,
    idx: usize,
};

const VarMap = struct {
    vars: []Var,
};

pub fn lexFile(io: std.Io, allocator: std.mem.Allocator, in: []const u8) ![]Token {
    var f = try std.Io.Dir.cwd().openFile(io, in, .{});
    defer f.close(io);

    var reader_buff: [1024]u8 = undefined;
    var reader = f.reader(io, &reader_buff);

    var result: std.array_list.Managed(Token) = .init(allocator);
    defer result.deinit();

    var buff: [1]u8 = undefined;
    var prev: u8 = '\n';
    var code: []u8 = &.{};
    while (true) {
        const size = try reader.interface.readSliceShort(&buff);
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
            var stmt = (try reader.interface.takeDelimiter('\n')).?;

            if (std.mem.eql(u8, stmt[0..8], "include ")) {
                const eon_path = stmt[10 .. stmt.len - 1];

                const path_size = std.mem.replacementSize(u8, eon_path, "/", &.{std.fs.path.sep});
                const path_buf = try allocator.alloc(u8, path_size);
                defer allocator.free(path_buf);

                _ = std.mem.replace(u8, eon_path, "/", &.{std.fs.path.sep}, path_buf);

                const path = try std.fs.path.join(allocator, &.{ lib_path, path_buf });

                var toks = try lexFile(io, allocator, path);
                defer allocator.free(toks);

                try result.appendSlice(toks[0 .. toks.len - 1]);
            }
            code = &.{};

            continue;
        }

        if (code.len != 0 and (std.mem.indexOf(u8, " @${}();,\t\n~![]", char_string) != null or std.mem.indexOf(u8, " $@{}();,\t\n~![]", code[code.len - 1 ..]) != null)) {
            if (Token.KIND_NAMES.get(code)) |kind| {
                try result.append(.{
                    .kind = kind,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (code.len > 1 and code.len != 0 and code[0] == '"' and code[code.len - 1] == '"') {
                try result.append(.{
                    .kind = .string_literal,
                    .value = code,
                });
                code = try allocator.alloc(u8, 0);
            } else if (!std.mem.eql(u8, code, "\"")) {
                if (code[0] == '-' and code.len != 1) {
                    try result.append(.{
                        .kind = .sub,
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
                        .kind = .ident,
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
                            .kind = .int_literal,
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
            _ = reader.interface.discardDelimiterInclusive('\n') catch |err| switch (err) {
                error.EndOfStream => {
                    try result.append(.{
                        .kind = .eof,
                        .value = "EOF",
                    });

                    return result.toOwnedSlice();
                },
                else => |e| return e,
            };
        } else if ((std.mem.indexOf(u8, "\t\r\n ", char_string) == null or (code.len != 0 and code[0] == '"'))) {
            code = try allocator.realloc(code, code.len + 1);
            code[code.len - 1] = char;
        }

        prev = char;
    }

    try result.append(.{
        .kind = .eof,
        .value = "EOF",
    });

    return result.toOwnedSlice();
}

const EMPTY_EXPR = [_]Expression{};

pub fn parseFactor(allocator: std.mem.Allocator, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) !Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    if (tokens[idx.*].kind == .open_paren) {
        idx.* += 1;
        var a = try allocator.alloc(Expression, 1);
        a[0] = try parseExpression(allocator, tokens, heap, idx);

        if (tokens[idx.*].kind != .close_paren) return error.NoClose;
        idx.* += 1;

        result = .{
            .a = a,
            .op = &tokens[idx.* - 1],
            .b = &EMPTY_EXPR,
        };

        return result;
    } else if (tokens[idx.*].kind == .int_literal or
        tokens[idx.*].kind == .string_literal or
        tokens[idx.*].kind == .ident)
    {
        if (tokens[idx.* + 1].kind == .mul or
            tokens[idx.* + 1].kind == .div or
            tokens[idx.* + 1].kind == .mod)
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
            b[0] = try parseFactor(allocator, tokens, heap, idx);
            result = .{
                .a = a,
                .op = op,
                .b = b,
            };
            return result;
        } else if (tokens[idx.* + 1].kind == .open_paren) {
            if (tokens[idx.*].kind != .ident) return error.NoIdent;
            var ident = &tokens[idx.*];
            idx.* += 2;
            var b = try allocator.alloc(Expression, 0);
            while (parseExpression(allocator, tokens, heap, idx) catch null) |expr| {
                b = try allocator.realloc(b, b.len + 1);
                b[b.len - 1] = expr;
                if (tokens[idx.*].kind != .comma) break;
                idx.* += 1;
            }
            if (tokens[idx.*].kind != .close_paren) return error.NoClose;
            idx.* += 1;

            ident.kind = .open_paren;

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
    } else if (tokens[idx.*].kind == .sub) {
        const ident = &tokens[idx.*];
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseFactor(allocator, tokens, heap, idx);

        result = .{
            .a = &EMPTY_EXPR,
            .op = ident,
            .b = b,
        };
        return result;
    } else if (tokens[idx.*].kind == .at or
        tokens[idx.*].kind == .heap_read or
        tokens[idx.*].kind == .keyword_new)
    {
        const ident = &tokens[idx.*];
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseFactor(allocator, tokens, heap, idx);

        result = .{
            .a = &EMPTY_EXPR,
            .op = ident,
            .b = b,
        };
        return result;
    }
    return error.NoFactor;
}

pub fn parseSum(allocator: std.mem.Allocator, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) !Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseFactor(allocator, tokens, heap, idx);

    if (tokens[idx.*].kind == .add or
        tokens[idx.*].kind == .cat or
        tokens[idx.*].kind == .sub)
    {
        const op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(allocator, tokens, heap, idx);
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

pub fn parseExpression(allocator: std.mem.Allocator, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) anyerror!Expression {
    var result: Expression = .{
        .a = &EMPTY_EXPR,
        .op = null,
        .b = &EMPTY_EXPR,
    };

    var a = try allocator.alloc(Expression, 1);
    a[0] = try parseSum(allocator, tokens, heap, idx);

    if (tokens[idx.*].kind == .and_op or
        tokens[idx.*].kind == .or_op or
        tokens[idx.*].kind == .lt or
        tokens[idx.*].kind == .gt or
        tokens[idx.*].kind == .eq or
        tokens[idx.*].kind == .not_eq or
        tokens[idx.*].kind == .assign or
        tokens[idx.*].kind == .heap_assign or
        tokens[idx.*].kind == .add_equals or
        tokens[idx.*].kind == .cat_equals or
        tokens[idx.*].kind == .sub_equals)
    {
        const op = &tokens[idx.*];
        idx.* += 1;

        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(allocator, tokens, heap, idx);
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

pub fn parseStatement(allocator: std.mem.Allocator, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) !Statement {
    var result: Statement = .{
        .kind = .STMT_INVALID,
        .name = null,
        .exprs = null,
        .blks = null,
    };
    if (tokens[idx.*].kind == .keyword_var) {
        idx.* += 1;
        if (tokens[idx.*].kind != .ident) return error.ExpectedIdent;

        result = .{
            .kind = .STMT_DECLARE,
            .name = tokens[idx.*].value,
            .exprs = null,
            .blks = null,
        };

        idx.* += 1;

        if (tokens[idx.*].kind == .assign) {
            idx.* += 1;
            var b = try allocator.alloc(Expression, 1);
            b[0] = try parseExpression(allocator, tokens, heap, idx);

            result.exprs = b;
        }
        if (tokens[idx.*].kind != .semi_colon) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .keyword_return) {
        idx.* += 1;
        var b = try allocator.alloc(Expression, 1);
        b[0] = try parseExpression(allocator, tokens, heap, idx);

        result = .{
            .kind = .STMT_RETURN,
            .name = null,
            .exprs = b,
            .blks = null,
        };
        if (tokens[idx.*].kind != .semi_colon) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .keyword_asm) {
        idx.* += 1;
        if (tokens[idx.*].kind != .string_literal) return error.ExpectedSC;

        result = .{
            .kind = .STMT_ASM,
            .name = tokens[idx.*].value,
            .exprs = null,
            .blks = null,
        };
        idx.* += 1;
        if (tokens[idx.*].kind != .semi_colon) return error.ExpectedSC;
        idx.* += 1;

        return result;
    } else if (tokens[idx.*].kind == .keyword_for) {
        idx.* += 1;
        if (tokens[idx.*].kind != .open_paren) return error.ExpectedParen;
        idx.* += 1;
        var exprs = try allocator.alloc(Expression, 2);
        var blks = try allocator.alloc([]Statement, 2);
        blks[0] = try allocator.alloc(Statement, 1);
        blks[0][0] = try parseStatement(allocator, tokens, heap, idx);
        exprs[0] = try parseExpression(allocator, tokens, heap, idx);
        if (tokens[idx.*].kind != .semi_colon) return error.Semi;
        idx.* += 1;
        exprs[1] = try parseExpression(allocator, tokens, heap, idx);
        if (tokens[idx.*].kind != .close_paren) return error.NoClose;
        idx.* += 1;
        blks[1] = try parseBlock(allocator, tokens, heap, idx);

        result = .{
            .kind = .STMT_FOR,
            .name = null,
            .exprs = exprs,
            .blks = blks,
        };

        return result;
    } else if (tokens[idx.*].kind == .keyword_while) {
        idx.* += 1;
        if (tokens[idx.*].kind != .open_paren) return error.ExpectedParen;
        idx.* += 1;
        var exprs = try allocator.alloc(Expression, 1);
        exprs[0] = try parseExpression(allocator, tokens, heap, idx);
        if (tokens[idx.*].kind != .close_paren) return error.NoClose;
        idx.* += 1;
        var blks = try allocator.alloc([]Statement, 1);
        blks[0] = try parseBlock(allocator, tokens, heap, idx);

        result = .{
            .kind = .STMT_WHILE,
            .name = null,
            .exprs = exprs,
            .blks = blks,
        };

        return result;
    } else if (tokens[idx.*].kind == .keyword_if) {
        idx.* += 1;
        if (tokens[idx.*].kind != .open_paren) return error.ExpectedParen;
        idx.* += 1;

        var s = try allocator.alloc(Expression, 1);
        s[0] = try parseExpression(allocator, tokens, heap, idx);

        if (tokens[idx.*].kind != .close_paren) return error.NoClose;
        idx.* += 1;

        var b = try allocator.alloc([]Statement, 1);
        b[0] = try parseBlock(allocator, tokens, heap, idx);

        if (tokens[idx.*].kind == .keyword_else) {
            idx.* += 1;
            b = try allocator.realloc(b, 2);
            b[1] = try parseBlock(allocator, tokens, heap, idx);
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
        b[0] = try parseExpression(allocator, tokens, heap, idx);

        result = .{
            .kind = .STMT_EXP,
            .name = null,
            .exprs = b,
            .blks = null,
        };

        if (tokens[idx.*].kind != .semi_colon) return error.ExpectedSC;
        idx.* += 1;

        return result;
    }

    return error.NoStmt;
}

pub fn parseBlock(allocator: std.mem.Allocator, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) anyerror![]Statement {
    var result: []Statement = undefined;

    if (tokens[idx.*].kind != .open_brace) {
        result = try allocator.alloc(Statement, 1);
        result[0] = try parseStatement(allocator, tokens, heap, idx);

        return result;
    }
    idx.* += 1;
    result = try allocator.alloc(Statement, 0);

    while (parseStatement(allocator, tokens, heap, idx) catch null) |stmt| {
        result = try allocator.realloc(result, result.len + 1);
        result[result.len - 1] = stmt;
    }

    if (tokens[idx.*].kind != .close_brace) return error.NoClose;
    idx.* += 1;

    return result;
}

pub fn parseFunctionParam(tokens: []Token, idx: *usize) !FunctionParam {
    var result: FunctionParam = .{
        .name = "",
    };

    if (tokens[idx.*].kind != .ident) return error.ExpectedValue;
    result.name = tokens[idx.*].value;
    idx.* += 1;

    return result;
}

pub fn parseFunctionDecl(allocator: std.mem.Allocator, fnPrefix: *[]const u8, tokens: []Token, heap: *std.array_list.Managed([]const u8), idx: *usize) !FunctionDecl {
    var result: FunctionDecl = undefined;
    if (tokens[idx.*].kind != .keyword_fn) return error.ExpectedType;
    idx.* += 1;
    if (tokens[idx.*].kind != .ident) return error.ExpectedIdent;
    result.ident = try allocator.print("{s}{s}", .{ fnPrefix.*, tokens[idx.*].value });
    idx.* += 1;
    if (tokens[idx.*].kind != .open_paren) return error.ExpectedParen;
    idx.* += 1;
    if (tokens[idx.*].kind != .close_paren) {
        result.params = try allocator.alloc(FunctionParam, 0);
        while (parseFunctionParam(tokens, idx) catch null) |param| {
            result.params = try allocator.realloc(result.params, result.params.len + 1);
            result.params[result.params.len - 1] = param;
            if (tokens[idx.*].kind != .comma) break;
            idx.* += 1;
        }
        if (tokens[idx.*].kind != .close_paren) return error.NoClose;
        idx.* += 1;
    } else {
        result.params = &[_]FunctionParam{};
        idx.* += 1;
    }

    result.stmts = try parseBlock(allocator, tokens, heap, idx);

    return result;
}

pub fn parseProgram(allocator: std.mem.Allocator, fn_prefix: *[]const u8, tokens: []Token) !Program {
    var result: Program = .{
        .funcs = try allocator.alloc(FunctionDecl, 0),
        .heap = .init(allocator),
    };

    var idx: usize = 0;
    while (true) {
        if (parseFunctionDecl(allocator, fn_prefix, tokens, &result.heap, &idx) catch null) |func| {
            result.funcs = try allocator.realloc(result.funcs, result.funcs.len + 1);
            result.funcs[result.funcs.len - 1] = func;
        } else if (tokens[idx].kind == .keyword_var) {
            idx += 1;
            if (tokens[idx].kind != .ident) return error.ExpectedIdent;
            try result.heap.append(tokens[idx].value);
            idx += 1;

            if (tokens[idx].kind != .semi_colon) return error.ExpectedIdent;
            idx += 1;
        } else if (tokens[idx].kind == .keyword_fnset) {
            idx += 1;
            if (tokens[idx].kind != .ident) return error.ExpectedIdent;
            const old_prefix = fn_prefix.*;
            defer allocator.free(old_prefix);
            fn_prefix.* = try allocator.print("{s}.", .{tokens[idx].value});
            idx += 1;
            if (tokens[idx].kind != .open_brace) return error.ExpectedIdent;
            idx += 1;
        } else if (tokens[idx].kind == .close_brace) {
            idx += 1;
            const dotidx = if (std.mem.lastIndexOf(u8, fn_prefix.*[0 .. fn_prefix.*.len - 1], ".")) |ind| ind + 1 else 0;

            fn_prefix.* = try allocator.dupe(u8, fn_prefix.*[0..dotidx]);
        } else {
            break;
        }
    }

    if (fn_prefix.len != 0) return error.POOPIE;

    if (tokens[idx].kind != .eof) {
        for (tokens[idx..]) |tok|
            std.log.info("toks: {s} '{s}'", .{ @tagName(tok.kind), tok.value });

        return error.ExpectedEOF;
    }

    idx += 1;

    return result;
}

pub fn compile_executable(io: std.Io, allocator: std.mem.Allocator, input_file: []const u8, output_file: []const u8) !void {
    var fn_prefix: []const u8 = "";

    const tokens = try lexFile(io, allocator, input_file);
    defer allocator.free(tokens);

    var prog = try parseProgram(allocator, &fn_prefix, tokens);

    var file = try std.Io.Dir.cwd().createFile(io, output_file, .{});
    defer file.close(io);

    var writer = file.writer(io, &.{});

    const adds = try prog.toAsm(allocator, false);
    try writer.interface.writeAll(adds);
}

pub fn compile_library(io: std.Io, allocator: std.mem.Allocator, input_file: []const u8, output_file: []const u8) !void {
    var fn_prefix: []const u8 = "";

    const tokens = try lexFile(io, allocator, input_file);
    defer allocator.free(tokens);

    var prog = try parseProgram(allocator, &fn_prefix, tokens);

    var file = try std.Io.Dir.cwd().createFile(io, output_file, .{});
    defer file.close(io);

    var writer = file.writer(io, &.{});

    const adds = try prog.toAsm(allocator, true);
    try writer.interface.writeAll(adds);
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    _ = args.next();

    const mode = args.next() orelse return error.MissingMode;
    lib_path = args.next() orelse return error.MissingLibPath;
    const input_file = args.next() orelse return error.MissingInputFile;
    const output_file = args.next() orelse return error.MissingOutputFile;

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();

    const alloc = arena.allocator();
    if (std.mem.eql(u8, mode, "exe")) {
        try compile_executable(init.io, alloc, input_file, output_file);
    } else if (std.mem.eql(u8, mode, "lib")) {
        try compile_library(init.io, alloc, input_file, output_file);
    } else return error.BadBuildMode;
}
