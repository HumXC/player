const std = @import("std");
const av = @import("av");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const assert = std.debug.assert;
const videoFile = "video.h264";
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
fn wrapAV(averror: c_int) !void {
    return switch (averror) {
        @intFromEnum(av.ERROR.BSF_NOT_FOUND) => return av.Error.BsfNotFound,
        @intFromEnum(av.ERROR.BUG) => return av.Error.FFmpegBug,
        @intFromEnum(av.ERROR.BUG2) => return av.Error.FFmpegBug,
        @intFromEnum(av.ERROR.BUFFER_TOO_SMALL) => return av.Error.BufferTooSmall,
        @intFromEnum(av.ERROR.DECODER_NOT_FOUND) => return av.Error.DecoderNotFound,
        @intFromEnum(av.ERROR.DEMUXER_NOT_FOUND) => return av.Error.DemuxerNotFound,
        @intFromEnum(av.ERROR.ENCODER_NOT_FOUND) => return av.Error.EncoderNotFound,
        @intFromEnum(av.ERROR.EOF) => return av.Error.EndOfFile,
        @intFromEnum(av.ERROR.EXIT) => return av.Error.FFmpegExit,
        @intFromEnum(av.ERROR.EXTERNAL) => return av.Error.FFmpegDependencyFailure,
        @intFromEnum(av.ERROR.UNKNOWN) => return av.Error.FFmpegDependencyFailure,
        @intFromEnum(av.ERROR.FILTER_NOT_FOUND) => return av.Error.FilterNotFound,
        @intFromEnum(av.ERROR.INVALIDDATA) => return av.Error.InvalidData,
        @intFromEnum(av.ERROR.MUXER_NOT_FOUND) => return av.Error.MuxerNotFound,
        @intFromEnum(av.ERROR.OPTION_NOT_FOUND) => return av.Error.OptionNotFound,
        @intFromEnum(av.ERROR.PATCHWELCOME) => return av.Error.FFmpegUnimplemented,
        @intFromEnum(av.ERROR.PROTOCOL_NOT_FOUND) => return av.Error.ProtocolNotFound,
        @intFromEnum(av.ERROR.STREAM_NOT_FOUND) => return av.Error.StreamNotFound,
        @intFromEnum(av.ERROR.EXPERIMENTAL) => return av.Error.FFmpegExperimentalFeature,
        @intFromEnum(av.ERROR.INPUT_CHANGED) => unreachable, // not legal to use with wrap()
        @intFromEnum(av.ERROR.OUTPUT_CHANGED) => unreachable, // not legal to use with wrap()
        @intFromEnum(av.ERROR.HTTP_BAD_REQUEST) => return av.Error.HttpBadRequest,
        @intFromEnum(av.ERROR.HTTP_UNAUTHORIZED) => return av.Error.HttpUnauthorized,
        @intFromEnum(av.ERROR.HTTP_FORBIDDEN) => return av.Error.HttpForbidden,
        @intFromEnum(av.ERROR.HTTP_NOT_FOUND) => return av.Error.HttpNotFound,
        @intFromEnum(av.ERROR.HTTP_OTHER_4XX) => return av.Error.HttpOther4xx,
        @intFromEnum(av.ERROR.HTTP_SERVER_ERROR) => return av.Error.Http5xx,
        else => return,
    };
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
    println("SDL error: {s}", .{sdl.SDL_GetError()});
    return error.SDLError;
}

const EncoderInitError = error{
    AllocBufferFailed,
    AllocFrameFailed,
    AllocPacketFailed,
    AllocFormatContextFailed,
    AllocCodecContextFailed,
};
fn ptrCast(comptime T: type, ptr: anytype) T {
    return @as(T, @ptrCast(ptr));
}
fn constPtrCast(comptime T: type, ptr: anytype) T {
    return ptrCast(T, @constCast(ptr));
}
pub fn main() !void {
    var video = try std.fs.cwd().openFile(videoFile, .{});
    defer video.close();
    const window = try newWindow("video player", 100, 100);
    defer window.close();
    const encoder = try newEncoder(&video);
    defer encoder.close();
    while (true) {
        const frame = encoder.reciveFrame() catch |e| {
            println("encoder exit: {}", .{e});
            break;
        };
        try window.drawFrame(frame);
        try window.showFrame();
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    println("QUIr", .{});
                    break;
                },
                sdl.SDL_WINDOWEVENT_RESIZED => {
                    println("resize", .{});
                    try window.setLogicalSize(event.window.data1, event.window.data2);
                    try window.showFrame();
                },
                else => {},
            }
        }
    }
}
const Window = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    var texture: ?*sdl.SDL_Texture = null;
    var width: i32 = 0;
    var height: i32 = 0;
    fn setLogicalSize(self: Window, w: i32, h: i32) !void {
        try wrapSDL(sdl.SDL_RenderSetLogicalSize(self.renderer, w, h));
    }
    fn showFrame(self: Window) !void {
        var winWidth: c_int = 0;
        var winHeight: c_int = 0;

        sdl.SDL_GetWindowSize(self.window, &winWidth, &winHeight);
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
        const destRect = sdl.SDL_Rect{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
        try wrapSDL(sdl.SDL_RenderCopy(self.renderer, texture, null, &destRect));
        sdl.SDL_RenderPresent(self.renderer);
    }
    fn drawFrame(self: Window, frame: *av.Frame) !void {
        const yPlane = frame.data[0];
        const uPlane = frame.data[1];
        const vPlane = frame.data[2];
        const yLinesize = frame.linesize[0];
        const uLinesize = frame.linesize[1];
        const vLinesize = frame.linesize[2];
        if (texture == null) {
            texture = sdl.SDL_CreateTexture(
                self.renderer,
                sdl.SDL_PIXELFORMAT_IYUV,
                sdl.SDL_TEXTUREACCESS_STREAMING,
                @as(c_int, @intCast(frame.width)),
                @as(c_int, @intCast(frame.height)),
            ) orelse {
                return throwSDL();
            };
        }

        try wrapSDL(sdl.SDL_UpdateYUVTexture(
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
    fn close(self: Window) void {
        sdl.SDL_DestroyRenderer(self.renderer);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }
};
fn newWindow(title: [*c]const u8, width: i32, height: i32) !Window {
    try wrapSDL(sdl.SDL_Init(sdl.SDL_INIT_EVENTS));
    const window = sdl.SDL_CreateWindow(
        title,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        sdl.SDL_WINDOW_BORDERLESS | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI,
    ) orelse {
        return throwSDL();
    };
    const renderer = sdl.SDL_CreateRenderer(
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
const Encoder = struct {
    packet: *av.Packet,
    frame: *av.Frame,

    formatCtx: *av.FormatContext,
    avioCtx: *av.IOContext,
    codecCtx: *av.CodecContext,
    buffer: [*]u8,
    fn reciveFrame(self: Encoder) !*av.Frame {
        av.av_packet_unref(self.packet);
        av.av_frame_unref(self.frame);
        try wrapAV(av.av_read_frame(self.formatCtx, self.packet));
        try wrapAV(av.avcodec_send_packet(self.codecCtx, self.packet));
        try wrapAV(av.avcodec_receive_frame(self.codecCtx, self.frame));
        return self.frame;
    }
    fn close(self: Encoder) void {
        av.av_packet_free(constPtrCast(*?*av.Packet, &self.packet));
        av.av_frame_free(constPtrCast(*?*av.Frame, &self.frame));
        av.avcodec_free_context(constPtrCast(*?*av.CodecContext, &self.codecCtx));
        av.avformat_close_input(constPtrCast(*?*av.FormatContext, &self.formatCtx));
    }
};

pub fn newEncoder(input: *std.fs.File) !Encoder {
    const bufferSize = 1024 * 1024;

    var formatCtx = av.avformat_alloc_context() orelse {
        return EncoderInitError.AllocFormatContextFailed;
    };

    const buffer = av.av_malloc(bufferSize) orelse {
        return EncoderInitError.AllocBufferFailed;
    };
    const avioCtx = av.avio_alloc_context(buffer, bufferSize, av.IOContext.WriteFlag.read_only, input, @ptrCast(&readPacket), null, null);
    formatCtx.pb = avioCtx;
    try wrapAV(av.avformat_open_input(@as(*?*av.FormatContext, @ptrCast(&formatCtx)), "", null, null));
    const bestStream = try formatCtx.find_best_stream(av.MediaType.VIDEO, -1, -1);
    const params = formatCtx.streams[bestStream[0]].*.codecpar;
    const codec = bestStream[1];
    const codecCtx = av.avcodec_alloc_context3(codec) orelse {
        return EncoderInitError.AllocCodecContextFailed;
    };

    try wrapAV(av.avcodec_parameters_to_context(codecCtx, params));
    try wrapAV(av.avcodec_open2(codecCtx, codec, null));

    return Encoder{
        .avioCtx = avioCtx,
        .formatCtx = formatCtx,
        .codecCtx = codecCtx,
        .buffer = buffer,
        .frame = av.av_frame_alloc() orelse {
            return EncoderInitError.AllocFrameFailed;
        },
        .packet = av.av_packet_alloc() orelse {
            return EncoderInitError.AllocPacketFailed;
        },
    };
}

fn readPacket(file: *std.fs.File, buffer: [*:0]u8, bufferSize: c_int) callconv(.C) c_int {
    _ = file.getPos() catch {
        return @as(c_int, @intFromEnum(av.ERROR.EXIT));
    };
    const n = file.read(buffer[0..@as(usize, @intCast(bufferSize))]) catch {
        return @as(c_int, @intFromEnum(av.ERROR.UNKNOWN));
    };
    if (n == 0) {
        return @as(c_int, @intFromEnum(av.ERROR.EOF));
    }
    return @as(c_int, @intCast(n));
}
