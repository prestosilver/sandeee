const options = @import("options");
const builtin = @import("builtin");
const std = @import("std");

const sandeee_data = @import("../data.zig");
const system = @import("../system.zig");
const util = @import("../util.zig");

const allocator = util.allocator;
const storage = util.storage;
const log = util.log;

const Vm = system.Vm;
const config = system.config;
const telem = system.telem;

const strings = sandeee_data.strings;
const fake = system.pseudo;
const Disk = system.Disk;

pub const FileError = error{
    InvalidPsuedoData,

    InvalidFileName,
    InvalidFolderName,

    FolderProtected,

    FolderNotFound,
    FileNotFound,

    FolderExists,
    FileExists,

    NotAFile,
    BadFile,

    WindowLimitReached,

    OutOfMemory,
} || std.Io.File.StatError || std.Io.File.SeekError || std.Io.File.Reader.Error || std.Io.File.Writer.Error ||
    std.Io.Reader.Error || std.Io.Writer.Error ||
    error{StreamTooLong} || util.SpriteBatch.Error || std.Io.File.OpenError;

pub const DiskError = error{
    BadDiskSize,

    OutOfMemory,

    AccessDenied,
    SystemResources,
    Unexpected,
    Unseekable,
    EndOfStream,
} || std.Io.Reader.Error || std.Io.File.LengthError || FileError;

pub var named_paths: std.EnumArray(NamedPath, ?Folder) = .initFill(null);
pub var enable_extr: bool = false;
pub var disk: Disk = undefined;

const root_prefix = if (builtin.is_test)
    "zig-out/bin/"
else
    "";

pub const NamedPath = enum {
    root,
    home,
    exec,
};

pub const LinkKind = enum {
    named,
    valid,
};

pub const Folder = Disk.Folder;
pub const File = Disk.File;

pub const FolderLink = union(LinkKind) {
    named: NamedPath,
    valid: Folder,

    pub const root = FolderLink{ .named = .root };
    pub const home = FolderLink{ .named = .home };
    pub const exec = FolderLink{ .named = .exec };
    pub fn link(f: Folder) FolderLink {
        return .{ .valid = f };
    }

    pub fn resolve(self: FolderLink) !Folder {
        switch (self) {
            .named => |n| {
                if (named_paths.get(n)) |named|
                    return named
                else
                    return error.FolderNotFound;
            },
            .valid => |v| return v,
        }
    }

    pub fn format(self: FolderLink, writer: anytype) !void {
        switch (self) {
            .named => |n| {
                if (named_paths.get(n)) |named|
                    return named.format(writer)
                else
                    return writer.print("?{s}?", .{@tagName(n)});
            },
            .valid => |v| return v.format(writer),
        }
    }
};
