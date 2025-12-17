const std = @import("std");
const builtin = @import("builtin");

const files = @import("../files.zig");
const allocator = @import("../../util/allocator.zig");
const vm = @import("../vm.zig");

pub const win = @import("window.zig");
pub const inp = @import("input.zig");
pub const snd = @import("snd.zig");
pub const gfx = @import("gfx.zig");

pub const all: []const files.Folder.FolderItem = if (builtin.is_test) &.{} else &.{
    .folder("win", &.{
        .file("new", .initFake(win.new)),
        .file("open", .initFake(win.open)),
        .file("destroy", .initFake(win.destroy)),
        .file("render", .initFake(win.render)),
        .file("flip", .initFake(win.flip)),
        .file("clear", .initFake(win.clear)),
        .file("title", .initFake(win.title)),
        .file("size", .initFake(win.size)),
        .file("rules", .initFake(win.rules)),
        .file("text", .initFake(win.text)),
    }),
    .folder("gfx", &.{
        .file("new", .initFake(gfx.new)),
        .file("pixel", .initFake(gfx.pixel)),
        .file("row", .initFake(gfx.row)),
        .file("destroy", .initFake(gfx.destroy)),
        .file("upload", .initFake(gfx.upload)),
        .file("save", .initFake(gfx.save)),
    }),
    .folder("snd", &.{
        .file("play", .initFake(snd.play)),
    }),
    .folder("inp", &.{
        .file("char", .initFake(inp.char)),
        .file("win", .initFake(inp.win)),
        .file("mouse", .initFake(inp.mouse)),
    }),
};
