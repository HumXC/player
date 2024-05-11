const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const ffmpeg = @import("ffmpeg.zig");
const sdl = @import("sdl.zig");
const videoFile = "video.h264";
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

pub fn main() !void {
    // var video = try std.fs.cwd().openFile(videoFile, .{});
    // defer video.close();
    var video = std.io.getStdIn();
    const window = try sdl.newWindow("video player", 100, 100);
    defer window.close();
    var t = std.time.milliTimestamp();
    var count: usize = 0;
    var decoder = try ffmpeg.newDecoder(&video);
    defer decoder.close();
    var isEOF = false;
    mainLoop: while (true) {
        if (!isEOF) {
            decoder.sendPacket() catch |e| {
                if (e == ffmpeg.Error.EndOfFile) {
                    println("EOF", .{});
                    isEOF = true;
                } else {
                    println("Error: {}", .{e});
                    break;
                }
            };
        }

        const frame = try decoder.reciveFrame() orelse {
            if (isEOF) {
                break :mainLoop;
            }
            continue;
        };

        count += 1;
        try window.drawFrame(frame);
        try window.showFrame();

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    println("Exit", .{});
                    break :mainLoop;
                },
                c.SDL_WINDOWEVENT_RESIZED => {
                    println("resize", .{});
                    try window.setLogicalSize(event.window.data1, event.window.data2);
                    try window.showFrame();
                },
                else => {},
            }
        }
        if (std.time.milliTimestamp() - t > 1000) {
            println("FPS: {}", .{count});
            count = 0;
            t = std.time.milliTimestamp();
        }
    }
    println("Exit", .{});
}
