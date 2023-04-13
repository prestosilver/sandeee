rm zig-out -rf && zig build -Dtarget=x86_64-linux -Doptimize=ReleaseFast upload
rm zig-out -rf && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast upload
rm zig-out -rf && zig build -Dtarget=x86_64-linux upload
rm zig-out -rf && zig build -Dtarget=x86_64-windows upload
