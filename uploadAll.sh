rm zig-out -rf && zig build -Doptimize=ReleaseFast upload
sleep 0.5
rm zig-out -rf && zig build upload
sleep 0.5
rm zig-out -rf && zig build -Ddemo -Doptimize=ReleaseFast upload
sleep 0.5
rm zig-out -rf && zig build -Ddemo upload
sleep 0.5
rm zig-out -rf && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast upload
sleep 0.5
rm zig-out -rf && zig build -Dtarget=x86_64-windows upload
sleep 0.5
rm zig-out -rf && zig build -Ddemo -Dtarget=x86_64-windows -Doptimize=ReleaseFast upload
sleep 0.5
rm zig-out -rf && zig build -Ddemo -Dtarget=x86_64-windows upload
