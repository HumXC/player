const std = @import("std");

const ffmpeg = @import("ffmpeg.zig");
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

pub fn main() !void {
    const decoder = try ffmpeg.newEncoder();
    defer decoder.close();
    while (true) {
        _ = try decoder.reciveFrame();
    }

    println("Exit", .{});
}
