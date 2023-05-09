rm zig-out -rf && zig build -Doptimize=ReleaseFast upload
sleep 1
rm zig-out -rf && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast upload
sleep 1
rm zig-out -rf && zig build upload
sleep 1
rm zig-out -rf && zig build -Dtarget=x86_64-windows upload
