const std = @import("std");
const rl = @import("raylib");
const screenWidth = 1280;
const screenHeight = 720;

pub fn main() !void {
    //1280
    //720

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);
    //make a connection thread

    var server_address = try std.net.Address.parseIp4("127.0.0.1", 8192);
    var connection_stream: std.net.Stream = undefined;

    var connection_thread = try std.Thread.spawn(.{}, manageConnection, .{ &connection_stream, &server_address });
    defer connection_thread.join();

    //   var read_buffer: [4096]u8 = undefined;
    //  var write_buffer: [4096]u8 = undefined;

    //  var stream_reader = connection_stream.reader(&read_buffer);
    //    var stream_writer = connection_stream.writer(&write_buffer);

    // var stream_in = &stream_reader.file_reader.interface;
    //   var stream_out = &stream_writer.interface;

    const background_image = try rl.loadImage("assets/green_texture.jpg");
    const background_texture = try rl.loadTextureFromImage(background_image);

    const card_back = try rl.loadImage("assets/bicycle-130/card_back.jpg");
    const card_back_texture = try rl.loadTextureFromImage(card_back);

    while (!rl.windowShouldClose()) {
        //    const input = try stream_in.takeDelimiterExclusive('\n');
        //   std.debug.print("READ INPUT: {s}\n", .{input});

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        rl.drawTexture(background_texture, 0, 0, .white);
        rl.drawTexture(card_back_texture, 0, 0, .white);
        //        rl.drawTexture
        //        you need to use draw textureEX to shrink these cards

        rl.drawText("Congrats! You Created your first window!", 190, 200, 20, .light_gray);
    }
}

pub fn manageConnection(stream: *std.net.Stream, address: *std.net.Address) !void {
    stream.* = try std.net.tcpConnectToAddress(address.*);
}
