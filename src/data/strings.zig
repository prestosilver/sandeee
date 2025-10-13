pub const BULLET = "\x80";
pub const LEFT = "\x81";
pub const E = "\x82";
pub const CHECK = "\x83";
pub const NOTEQUAL = "\x84";
pub const META = "\x85";
pub const FRAME = "\x86";
pub const DOWN = "\x87";
pub const BLOCK_ZERO = "\x88";

pub fn BLOCK(comptime id: u8) u8 {
    if (id > 7) @compileError("Bad Block char");

    return id + BLOCK_ZERO;
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
