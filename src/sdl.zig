const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const ffmpeg = @import("ffmpeg.zig");
const std = @import("std");
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
fn throwSDL() anyerror {
    wrapSDL(-1) catch |e| {
        return e;
    };
    return error.SDLError;
}
fn wrapSDL(sdlerror: c_int) !void {
    if (sdlerror == 0) {
        return;
    }
    println("SDL error: {s}", .{c.SDL_GetError()});
    return error.SDLError;
}
const Window = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    var texture: ?*c.SDL_Texture = null;
    var width: i32 = 0;
    var height: i32 = 0;
    pub fn setLogicalSize(self: Window, w: i32, h: i32) !void {
        try wrapSDL(c.SDL_RenderSetLogicalSize(self.renderer, w, h));
    }
    pub fn showFrame(self: Window) !void {
        var winWidth: c_int = 0;
        var winHeight: c_int = 0;

        c.SDL_GetWindowSize(self.window, &winWidth, &winHeight);
        const winRatio = @as(f32, @floatFromInt(winWidth)) / @as(f32, @floatFromInt(winHeight));
        const frameRatio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
        var x: c_int = 0;
        var y: c_int = 0;
        var w: c_int = 0;
        var h: c_int = 0;
        var scale: f32 = 1;
        if (winRatio < frameRatio) {
            scale = @as(f32, @floatFromInt(winWidth)) / @as(f32, @floatFromInt(width));
            w = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(width)) * scale));
            h = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(height)) * scale));
            x = 0;
            y = @divFloor((winHeight - h), 2);
        } else {
            scale = @as(f32, @floatFromInt(winHeight)) / @as(f32, @floatFromInt(height));
            w = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(width)) * scale));
            h = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(height)) * scale));
            x = @divFloor((winWidth - w), 2);
            y = 0;
        }
        const destRect = c.SDL_Rect{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
        try wrapSDL(c.SDL_RenderCopy(self.renderer, texture, null, &destRect));
        c.SDL_RenderPresent(self.renderer);
    }
    pub fn drawFrame(self: Window, frame: *ffmpeg.Frame) !void {
        const yPlane = frame.data[0];
        const uPlane = frame.data[1];
        const vPlane = frame.data[2];
        const yLinesize = frame.linesize[0];
        const uLinesize = frame.linesize[1];
        const vLinesize = frame.linesize[2];
        if (texture == null) {
            texture = c.SDL_CreateTexture(
                self.renderer,
                c.SDL_PIXELFORMAT_IYUV,
                c.SDL_TEXTUREACCESS_STREAMING,
                @as(c_int, @intCast(frame.width)),
                @as(c_int, @intCast(frame.height)),
            ) orelse {
                return throwSDL();
            };
        }

        try wrapSDL(c.SDL_UpdateYUVTexture(
            texture,
            null,
            yPlane,
            yLinesize,
            uPlane,
            uLinesize,
            vPlane,
            vLinesize,
        ));
        width = frame.width;
        height = frame.height;
    }
    pub fn close(self: Window) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};
pub fn newWindow(title: [*c]const u8, width: i32, height: i32) !Window {
    try wrapSDL(c.SDL_Init(c.SDL_INIT_EVENTS));
    const window = c.SDL_CreateWindow(
        title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_ALLOW_HIGHDPI,
    ) orelse {
        return throwSDL();
    };
    const renderer = c.SDL_CreateRenderer(
        window,
        -1,
        0,
    ) orelse {
        return throwSDL();
    };
    return Window{
        .window = window,
        .renderer = renderer,
    };
}
