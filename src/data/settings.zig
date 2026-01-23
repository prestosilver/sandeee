pub const Panel = struct {
    name: []const u8,
    icon: u8,
    entries: []const SettingEntry,
};

pub const SettingEntry = struct {
    pub const Kind = enum(u8) { string, dropdown, slider, file, folder };

    setting: []const u8,
    key: []const u8,

    kind: union(Kind) {
        string: void,
        dropdown: []const []const u8,
        slider: struct { min: f32, max: f32 },
        file: void,
        folder: void,

        pub const boolean = @This(){ .dropdown = &.{ "No", "Yes" } };
    },
};

pub const SETTINGS = [_]Panel{
    .{ .name = "Graphics", .icon = 2, .entries = &.{
        .{ .setting = "Wallpaper Color", .key = "wallpaper_color", .kind = .string },
        .{ .setting = "Wallpaper Mode", .key = "wallpaper_mode", .kind = .{ .dropdown = &.{ "Color", "Tile", "Center", "Stretch" } } },
        .{ .setting = "Accent Color", .key = "accent_color", .kind = .string },
        .{ .setting = "Wallpaper", .key = "wallpaper_path", .kind = .file },
        .{ .setting = "System font", .key = "system_font", .kind = .file },
        .{ .setting = "CRT Shader", .key = "crt_shader", .kind = .boolean },
    } },
    .{ .name = "Sounds", .icon = 1, .entries = &.{
        .{ .setting = "Sound Volume", .key = "sound_volume", .kind = .string },
        .{ .setting = "Sound Muted", .key = "sound_muted", .kind = .boolean },
        .{ .setting = "Login Sound", .key = "login_sound_path", .kind = .file },
        .{ .setting = "Message Sound", .key = "message_sound_path", .kind = .file },
        .{ .setting = "Logout Sound", .key = "logout_sound_path", .kind = .file },
    } },
    .{ .name = "Files", .icon = 3, .entries = &.{
        .{ .setting = "Show Hidden Files", .key = "explorer_hidden", .kind = .boolean },
        .{ .setting = "Web homepage", .key = "web_home", .kind = .string },
    } },
    .{ .name = "System", .icon = 0, .entries = &.{
        .{ .setting = "Scroll speed multiplier", .key = "scroll_speed", .kind = .{ .slider = .{ .min = 0.5, .max = 3.0 } } },
        .{ .setting = "window update rate", .key = "refresh_rate", .kind = .{ .slider = .{ .min = 0.1, .max = 5.0 } } },
        .{ .setting = "Show Welcome", .key = "show_welcome", .kind = .boolean },
        .{ .setting = "Startup Script", .key = "startup_file", .kind = .file },
    } },
};
