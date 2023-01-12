const std = @import("std");
const eql = std.mem.eql;

fn isFuncT(comptime T: type) type {
    return @typeInfo(T) == .Function;
}

fn ReturnType(comptime func: type) type {
    if (isFuncT(func))
        return @typeInfo(func).Function.return_type
    else
        @compileError("Not a func");
}

pub fn LambdaT(comptime closureT: type, comptime func: anytype) type {
    return LambdaTFuncT(closureT, @TypeOf(func));
}

pub fn LambdaTFuncT(comptime closureT: type, comptime func: anytype) type {
    return struct {
        closure: *closureT,
        pub fn call(self: @This(), args: anytype) ReturnType(func) {
            return @call(.{}, func, .{ self.closure } ++ args);
        }
    };
}

pub fn lambda(closure: anytype, comptime func: anytype) LambdaT(@TypeOf(closure), func) {
    const LambdaType = LambdaT(@TypeOf(closure), func);
    return LambdaType { .closure = closure };
}
