const std = @import("std");
const av = @import("av");
pub const Frame = av.Frame;
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
pub const Error = av.Error;
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
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
const EAGAIN: c_int = -11;
pub const Decoder = struct {
    packet: *av.Packet,
    frame: *av.Frame,
    formatCtx: *av.FormatContext,
    avioCtx: *av.IOContext,
    codecCtx: *av.CodecContext,
    codec: *const av.Codec,
    buffer: [*]u8,
    var hasFrame: bool = false;
    pub fn sendPacket(self: Decoder) !void {
        var ret: c_int = 0;
        try wrapAV(av.av_read_frame(self.formatCtx, self.packet));
        ret = av.avcodec_send_packet(self.codecCtx, self.packet);
        try wrapAV(ret);
        if (ret == EAGAIN) {
            return error.EAGAIN;
        }
    }
    pub fn reciveFrame(self: Decoder) !?*av.Frame {
        const ret = av.avcodec_receive_frame(self.codecCtx, self.frame);
        try wrapAV(ret);
        if (ret < 0) {
            return null;
        }
        return self.frame;
    }

    pub fn getFrame(self: Decoder) ?*av.Frame {
        if (hasFrame) {
            hasFrame = false;
            return self.frame;
        }
        return null;
    }

    pub fn close(self: Decoder) void {
        av.av_packet_unref(self.packet);
        av.av_frame_unref(self.frame);
        av.av_packet_free(constPtrCast(*?*av.Packet, &self.packet));
        av.av_frame_free(constPtrCast(*?*av.Frame, &self.frame));
        av.avcodec_free_context(constPtrCast(*?*av.CodecContext, &self.codecCtx));
        av.avformat_close_input(constPtrCast(*?*av.FormatContext, &self.formatCtx));
    }
};

pub fn newDecoder(input: *std.fs.File) !Decoder {
    const bufferSize = 1024 * 1024 * 4;

    var formatCtx = av.avformat_alloc_context() orelse {
        return EncoderInitError.AllocFormatContextFailed;
    };

    const buffer = av.av_malloc(bufferSize) orelse {
        return EncoderInitError.AllocBufferFailed;
    };
    const avioCtx = av.avio_alloc_context(buffer, bufferSize, av.IOContext.WriteFlag.read_only, input, @ptrCast(&readPacket), null, null);
    formatCtx.pb = avioCtx;
    try wrapAV(av.avformat_open_input(@as(*?*av.FormatContext, @ptrCast(&formatCtx)), "", null, null));
    // try wrapAV(av.avformat_find_stream_info(formatCtx, null));
    const bestStream = try formatCtx.find_best_stream(av.MediaType.VIDEO, -1, -1);
    const params = formatCtx.streams[bestStream[0]].*.codecpar;
    const codec: *const av.Codec = bestStream[1];
    const codecCtx = av.avcodec_alloc_context3(codec) orelse {
        return EncoderInitError.AllocCodecContextFailed;
    };
    codecCtx.thread_count = 0;
    try wrapAV(av.avcodec_parameters_to_context(codecCtx, params));
    try wrapAV(av.avcodec_open2(codecCtx, codec, null));
    const decoder = Decoder{
        .avioCtx = avioCtx,
        .formatCtx = formatCtx,
        .codecCtx = codecCtx,
        .buffer = buffer,
        .codec = codec,
        .frame = av.av_frame_alloc() orelse {
            return EncoderInitError.AllocFrameFailed;
        },
        .packet = av.av_packet_alloc() orelse {
            return EncoderInitError.AllocPacketFailed;
        },
    };
    return decoder;
}

fn readPacket(file: *std.fs.File, buffer: [*:0]u8, bufferSize: c_int) callconv(.C) c_int {
    const n = file.read(buffer[0..@as(usize, @intCast(bufferSize))]) catch {
        return @as(c_int, @intFromEnum(av.ERROR.UNKNOWN));
    };
    if (n == 0) {
        return @as(c_int, @intFromEnum(av.ERROR.EOF));
    }
    return @as(c_int, @intCast(n));
}
