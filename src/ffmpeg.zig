const std = @import("std");
const avcodec = @cImport("avcodec/avcodec.h");
const av = @import("av");

pub const Frame = av.Frame;
pub const Error = av.Error;
const AV_CODEC_FLAG_LOW_DELAY = 1 << 19;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
const EAGAIN: c_int = -11;
pub const Decoder = struct {
    formatCtx: *av.FormatContext,
    avioCtx: *av.IOContext,
    codecCtx: *av.CodecContext,
    codec: *const av.Codec,
    buffer: []u8,
    packet: *av.Packet,
    frame: *av.Frame,
    streamID: c_uint,
    var hasFrame: bool = false;
    pub fn sendPacket(self: Decoder) !void {
        try av.FormatContext.read_frame(self.formatCtx, self.packet);
        try self.codecCtx.send_packet(self.packet);
    }
    pub fn reciveFrame(self: Decoder) !?*Frame {
        self.codecCtx.receive_frame(self.frame) catch |e| {
            if (e == av.Error.WouldBlock) {
                return null;
            } else {
                return e;
            }
        };
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
        self.codecCtx.free();
        self.formatCtx.close_input();
        self.avioCtx.free();
    }
};

pub fn newDecoder(input: *std.fs.File) !Decoder {
    const bufferSize = 1024 * 1024 * 2;
    const buffer = try av.malloc(bufferSize);
    const avioCtx = try av.IOContext.alloc(buffer, av.IOContext.WriteFlag.read_only, input, @ptrCast(&readPacket), null, null);
    var formatCtx = try av.FormatContext.open_input("", null, null, avioCtx);
    // try formatCtx.find_stream_info(null);
    const bestStream = try formatCtx.find_best_stream(av.MediaType.VIDEO, -1, -1);
    const params = formatCtx.streams[bestStream[0]].*.codecpar;
    const codec: *const av.Codec = bestStream[1];
    const codecCtx = try av.CodecContext.alloc(codec);
    codecCtx.thread_count = 0;
    try codecCtx.parameters_to_context(params);
    try codecCtx.open(codec, null);
    const decoder = Decoder{
        .avioCtx = avioCtx,
        .formatCtx = formatCtx,
        .codecCtx = codecCtx,
        .buffer = buffer,
        .codec = codec,
        .streamID = bestStream[0],
        .packet = try av.Packet.alloc(),
        .frame = try av.Frame.alloc(),
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
