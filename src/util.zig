const std = @import("std");
const builtin = @import("builtin");

pub const graphics = @import("util/graphics.zig");
pub const storage = @import("util/storage.zig");
pub const logger = @import("util/log.zig");
pub const panic = @import("util/panic.zig");
pub const audio = @import("util/audio.zig");
pub const http = @import("util/http.zig");
pub const log = @import("util/log.zig").log;
pub const TextureManager = @import("util/TextureManager.zig");
pub const SpriteBatch = @import("util/SpriteBatch.zig");
pub const Allocator = @import("util/Allocator.zig");
pub const VertArray = @import("util/VertArray.zig");
pub const Shader = @import("util/Shader.zig");
pub const Texture = @import("util/Texture.zig");
pub const Rope = @import("util/RopeOld.zig");
pub const Font = @import("util/Font.zig");
pub const Url = @import("util/Url.zig");
pub const Eln = @import("util/Eln.zig");

pub const allocator = Allocator.allocator;

pub inline fn deinitAllocator() void {
    if (!builtin.link_libc or !Allocator.useclib) {
        std.debug.assert(Allocator.gpa.deinit() == .ok);
    }
}

test {
    _ = Eln;
    _ = Rope;
    _ = storage;
    _ = Url;
}
