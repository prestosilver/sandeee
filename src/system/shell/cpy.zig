const system = @import("../mod.zig");
const util = @import("../../util/mod.zig");

const Shell = system.Shell;
const files = system.files;

const allocator = util.allocator;

pub fn cpy(self: *Shell, params: *Shell.Params) !Shell.Result {
    const input = params.next() orelse return error.MissingParameter;
    const output = params.next() orelse return error.MissingParameter;
    const root_link: files.FolderLink = if (input.len != 0 and input[0] == '/')
        .root
    else
        self.root;
    const output_root_link: files.FolderLink = if (output.len != 0 and output[0] == '/')
        .root
    else
        self.root;

    const root = try root_link.resolve();
    const output_root = try output_root_link.resolve();
    const file = try root.getFile(input);

    // TODO: implement copy to folder
    // if (output_root.getFolder()) {}
    try output_root.newFile(output);
    const targ = try output_root.getFile(output);
    try file.copyOver(targ);
    return .{
        .data = try allocator.alloc.dupe(u8, "Copied"),
    };
}
