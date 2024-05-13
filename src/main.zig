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
    const decoder = try ffmpeg.newDecoder(&video);
    defer decoder.close();
    var fpsTime = std.time.milliTimestamp();
    var fpsCount: usize = 0;
    var t = std.time.milliTimestamp();
    t = 0;
    var isEOF = false;
    mainLoop: while (true) {
        decoder.sendPacket() catch |e| {
            switch (e) {
                error.EndOfFile => {
                    println("EOF", .{});
                    isEOF = true;
                },
                error.WouldBlock => {
                    continue;
                },
                else => {
                    println("Error: {}", .{e});
                    isEOF = true;
                },
            }
        };
        const frame = decoder.reciveFrame() catch |e| {
            switch (e) {
                error.EndOfFile => {
                    break :mainLoop;
                },
                else => {
                    println("Error: {}", .{e});
                    break :mainLoop;
                },
            }
        } orelse {
            if (isEOF) {
                break :mainLoop;
            }
            continue;
        };
        try window.drawFrame(frame);
        try window.showFrame();
        fpsCount += 1;
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    break :mainLoop;
                },
                c.SDL_WINDOWEVENT_RESIZED => {
                    try window.setLogicalSize(event.window.data1, event.window.data2);
                    try window.showFrame();
                },
                else => {},
            }
        }
        if (std.time.milliTimestamp() - fpsTime > 1000) {
            fpsCount = 0;
            fpsTime = std.time.milliTimestamp();
        }
    }
    println("Exit", .{});
}
