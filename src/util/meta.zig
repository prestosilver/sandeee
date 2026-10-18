const std = @import("std");

fn checkSize(Self: type, comptime expected: usize) void {
    if (@sizeOf(Self) != expected) {
        const info = @typeInfo(Self);

        var pos: usize = 0;

        for (
            info.@"struct".field_types,
            info.@"struct".field_names,
        ) |T, name| {
            const offset = @offsetOf(Self, name);
            @compileLog(std.fmt.comptimePrint(
                "field: '{s}' size: {} offset {}: total {}",
                .{ @sizeOf(T), name, offset, pos },
            ));
            pos += @sizeOf(T);
        }

        @compileError(std.fmt.comptimePrint(
            "This is super bad, the {} type is not the right size got {} expected {} ({})",
            .{ @typeName(Self), @sizeOf(Self), expected, @typeInfo(Self) },
        ));
    }
}
