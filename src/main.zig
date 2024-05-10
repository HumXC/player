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
    var video = try std.fs.cwd().openFile(videoFile, .{});
    defer video.close();
    const window = try sdl.newWindow("video player", 100, 100);
    defer window.close();
    const encoder = try ffmpeg.newEncoder(&video);
    defer encoder.close();
    mainLoop: while (true) {
        const frame = encoder.reciveFrame() catch |e| {
            if (e == error.EndOfFile) {
                break :mainLoop;
            }
            println("decoder exit: {}", .{e});
            break;
        };
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
    }
    println("Exit", .{});
}
