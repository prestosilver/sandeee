pub const Stream = @import("system/Stream.zig");
pub const Opener = @import("system/Opener.zig");
pub const Shell = @import("system/Shell.zig");
pub const Vm = @import("system/Vm.zig");
pub const syscalls = @import("system/syscalls.zig");
pub const headless = @import("system/headless.zig");
pub const config = @import("system/config.zig");
pub const telem = @import("system/telem.zig");
pub const files = @import("system/files.zig");
pub const mail = @import("system/mail.zig");
pub const pseudo = @import("system/pseudo.zig");

test {
    _ = headless;
    _ = Shell;
    _ = Vm;
}
