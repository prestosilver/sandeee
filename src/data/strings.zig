const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const util = @import("../util.zig");
const data = @import("../data.zig");

const Version = data.Version;

const allocator = util.allocator;

pub const NO_STACKTRACE_MESSAGE: []const u8 = "Stacktrace Unavailable\n";

pub const CLEAR = "\x01";
pub const UNDO = "\x08";

pub const BULLET = "\x80";
pub const LEFT = "\x81";
pub const E = "\x82";
pub const CHECK = "\x83";
pub const NOTEQUAL = "\x84";
pub const META = "\x85";
pub const FRAME = "\x86";
pub const DOWN = "\x87";

const SANDEEE_VERSION = Version{
    .program = options.SANDEEE_VERSION.program,
    .phase = @enumFromInt(@intFromEnum(options.SANDEEE_VERSION.phase)),
    .index = options.SANDEEE_VERSION.index,
    .meta = options.SANDEEE_VERSION.meta,
};
pub const SANDEEE_VERSION_TEXT = std.fmt.comptimePrint("{f}", .{SANDEEE_VERSION});

pub fn BLOCK(comptime id: u8) []const u8 {
    if (id > 7) @compileError("Bad Block char");

    return &.{id + '\x88'};
}

pub const DOTS = "\x90";
pub const RIGHT = "\x91";
pub const SMILE = "\x92";
pub const STRAIGHT = "\x93";
pub const SAD = "\x94";
pub const UP = "\x97";

pub const COLOR_BLACK = "\xF0";
pub const COLOR_GRAY = "\xF1";
pub const COLOR_DARK_RED = "\xF2";
pub const COLOR_DARK_YELLOW = "\xF3";
pub const COLOR_DARK_GREEN = "\xF4";
pub const COLOR_DARK_CYAN = "\xF5";
pub const COLOR_DARK_BLUE = "\xF6";
pub const COLOR_DARK_MAGENTA = "\xF7";

pub const COLOR_WHITE = "\xF9";
pub const COLOR_RED = "\xFA";
pub const COLOR_YELLOW = "\xFB";
pub const COLOR_GREEN = "\xFC";
pub const COLOR_CYAN = "\xFD";
pub const COLOR_BLUE = "\xFE";
pub const COLOR_MAGENTA = "\xFF";

pub const EEE = E ** 3;

const CharReplacement = struct {
    pub const StringKind = enum { eeech, ansi, unicode, ascii };

    eeech: []const u8,
    ansi: []const u8 = "",
    unicode: []const u8 = "",
    ascii: []const u8 = "",
};

const REPLACEMENT_TABLE = [_]CharReplacement{
    .{ .eeech = BULLET, .ansi = "•", .unicode = "•", .ascii = "-" },
    .{ .eeech = RIGHT, .ansi = "▶", .unicode = "▶", .ascii = ">" },
    .{ .eeech = E, .ansi = "Ⲉ", .unicode = "Ⲉ", .ascii = "E" },
    .{ .eeech = CHECK, .ansi = "✓", .unicode = "✓", .ascii = "X" },
    .{ .eeech = NOTEQUAL, .ansi = "≠", .unicode = "≠", .ascii = "!=" },
    .{ .eeech = META, .ansi = "ϻ", .unicode = "ϻ", .ascii = "Mb" },
    .{ .eeech = FRAME, .ansi = "ℱ", .unicode = "ℱ", .ascii = "Fr" },
    .{ .eeech = DOWN, .ansi = "▼", .unicode = "▼", .ascii = "V" },
    .{ .eeech = BLOCK(0), .ansi = " ", .unicode = " ", .ascii = " " },
    .{ .eeech = BLOCK(1), .ansi = "▁", .unicode = "▁", .ascii = "-" },
    .{ .eeech = BLOCK(2), .ansi = "▂", .unicode = "▂", .ascii = "-" },
    .{ .eeech = BLOCK(3), .ansi = "▃", .unicode = "▃", .ascii = "+" },
    .{ .eeech = BLOCK(4), .ansi = "▄", .unicode = "▄", .ascii = "+" },
    .{ .eeech = BLOCK(5), .ansi = "▅", .unicode = "▅", .ascii = "#" },
    .{ .eeech = BLOCK(6), .ansi = "▆", .unicode = "▆", .ascii = "#" },
    .{ .eeech = BLOCK(7), .ansi = "▇", .unicode = "▇", .ascii = "#" },

    .{ .eeech = DOTS, .ansi = "…", .unicode = "…", .ascii = "..." },
    .{ .eeech = LEFT, .ansi = "◀", .unicode = "◀", .ascii = "<" },
    .{ .eeech = SMILE, .ansi = "☺", .unicode = "☺", .ascii = ":)" },
    .{ .eeech = STRAIGHT, .ansi = "😐", .unicode = "😐", .ascii = ":|" },
    .{ .eeech = SAD, .ansi = "☹", .unicode = "☹", .ascii = ":(" },
    .{ .eeech = UP, .ansi = "▲", .unicode = "▲", .ascii = "^" },

    .{ .eeech = "\x1b", .ansi = "^[" },
} ++ if (builtin.is_test) [_]CharReplacement{
    .{ .eeech = COLOR_BLACK },
    .{ .eeech = COLOR_GRAY },
    .{ .eeech = COLOR_DARK_RED },
    .{ .eeech = COLOR_DARK_YELLOW },
    .{ .eeech = COLOR_DARK_GREEN },
    .{ .eeech = COLOR_DARK_CYAN },
    .{ .eeech = COLOR_DARK_BLUE },
    .{ .eeech = COLOR_DARK_MAGENTA },

    .{ .eeech = COLOR_WHITE },
    .{ .eeech = COLOR_RED },
    .{ .eeech = COLOR_YELLOW },
    .{ .eeech = COLOR_GREEN },
    .{ .eeech = COLOR_CYAN },
    .{ .eeech = COLOR_BLUE },
    .{ .eeech = COLOR_MAGENTA },

    .{ .eeech = CLEAR },
    .{ .eeech = UNDO },

    .{ .eeech = "\xf8" },

    .{ .eeech = "\r" },
} else [_]CharReplacement{
    .{ .eeech = COLOR_BLACK, .ansi = "\x1b[0;30m" },
    .{ .eeech = COLOR_GRAY, .ansi = "\x1b[0;90m" },
    .{ .eeech = COLOR_DARK_RED, .ansi = "\x1b[0;31m" },
    .{ .eeech = COLOR_DARK_YELLOW, .ansi = "\x1b[0;33m" },
    .{ .eeech = COLOR_DARK_GREEN, .ansi = "\x1b[0;32m" },
    .{ .eeech = COLOR_DARK_CYAN, .ansi = "\x1b[0;36m" },
    .{ .eeech = COLOR_DARK_BLUE, .ansi = "\x1b[0;34m" },
    .{ .eeech = COLOR_DARK_MAGENTA, .ansi = "\x1b[0;35m" },

    .{ .eeech = COLOR_WHITE, .ansi = "\x1b[0;37m" },
    .{ .eeech = COLOR_RED, .ansi = "\x1b[0;91m" },
    .{ .eeech = COLOR_YELLOW, .ansi = "\x1b[0;93m" },
    .{ .eeech = COLOR_GREEN, .ansi = "\x1b[0;92m" },
    .{ .eeech = COLOR_CYAN, .ansi = "\x1b[0;96m" },
    .{ .eeech = COLOR_BLUE, .ansi = "\x1b[0;94m" },
    .{ .eeech = COLOR_MAGENTA, .ansi = "\x1b[0;95m" },

    .{ .eeech = CLEAR, .ansi = "\x1b[2J\x1b[H" },
    .{ .eeech = UNDO, .ansi = "\x1b[D \x1b[D" },

    .{ .eeech = "\xf8", .ansi = "\x1b[m" },

    .{ .eeech = "\r", .ansi = "\r\x1b[0K" },
    .{ .eeech = "\n", .ansi = "\n\r\x1b[0K", .unicode = "\n" },
};

pub fn encode(
    input: []const u8,
    comptime input_kind: CharReplacement.StringKind,
    comptime output_kind: CharReplacement.StringKind,
) ![]const u8 {
    var len: usize = 0;
    {
        var idx: usize = 0;
        outer: while (idx < input.len) {
            // Hack: zero is non printing in all formats here
            if (input[idx] == 0) {
                idx += 1;
                continue;
            }

            inline for (REPLACEMENT_TABLE) |entry| {
                const entry_input = switch (input_kind) {
                    .eeech => entry.eeech,
                    .ansi => entry.ansi,
                    .ascii => entry.ascii,
                    .unicode => entry.unicode,
                };
                const entry_output = switch (output_kind) {
                    .eeech => entry.eeech,
                    .ansi => entry.ansi,
                    .ascii => entry.ascii,
                    .unicode => entry.unicode,
                };

                if (entry_input.len == 0) continue;

                if (std.mem.startsWith(u8, input[idx..], entry_input)) {
                    len += entry_output.len;
                    idx += entry_input.len;

                    continue :outer;
                }
            }

            len += 1;
            idx += 1;
        }
    }

    var result = try allocator.alloc(u8, len);

    {
        var out_idx: usize = 0;
        var idx: usize = 0;
        outer: while (idx < input.len) {
            // Hack: zero is non printing in all formats here
            if (input[idx] == 0) {
                idx += 1;
                continue;
            }

            inline for (REPLACEMENT_TABLE) |entry| {
                const entry_input = switch (input_kind) {
                    .eeech => entry.eeech,
                    .ansi => entry.ansi,
                    .ascii => entry.ascii,
                    .unicode => entry.unicode,
                };
                const entry_output = switch (output_kind) {
                    .eeech => entry.eeech,
                    .ansi => entry.ansi,
                    .ascii => entry.ascii,
                    .unicode => entry.unicode,
                };

                if (entry_input.len == 0) continue;

                if (std.mem.startsWith(u8, input[idx..], entry_input)) {
                    @memcpy(result[out_idx .. out_idx + entry_output.len], entry_output);
                    out_idx += entry_output.len;
                    idx += entry_input.len;

                    continue :outer;
                }
            }

            result[out_idx] = input[idx];
            out_idx += 1;
            idx += 1;
        }
    }

    return result;
}

pub const ASM_HEADER = "EEEp";

pub const ROOT_PATH = "/";
pub const TELEM_DATA_PATH = "/_priv/telem.bin";
pub const EMAIL_DATA_PATH = "/_priv/email.bin";
pub const MAIL_PATH = "/cont/mail/";
pub const SETTINGS_PATH = "/conf/system.cfg";
pub const OPENER_PATH = "/conf/opener.cfg"; // TODO: this should problaby be a setting
pub const RECOVERY_METADATA_PATH = "/_recovery_meta";

pub const FAKE_PATH = "/fake/";
pub const PROF_PATH = "/prof/";
pub const EXEC_PATH = "/exec/";
pub const EXTR_PATH = "/extr/";
