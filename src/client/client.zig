const std = @import("std");

pub fn main() !void {
    const server_address = try std.net.Address.parseIp4("127.0.0.1", 8192);
    var connection_stream = try std.net.tcpConnectToAddress(server_address);

    var read_buffer: [4096]u8 = undefined;
    //  var write_buffer: [4096]u8 = undefined;

    var stream_reader = connection_stream.reader(&read_buffer);
    //    var stream_writer = connection_stream.writer(&write_buffer);

    var stream_in = &stream_reader.file_reader.interface;
    //   var stream_out = &stream_writer.interface;

    while (true) {
        const input = try stream_in.takeDelimiterExclusive('\n');
        std.debug.print("READ INPUT: {s}\n", .{input});
    }
}
