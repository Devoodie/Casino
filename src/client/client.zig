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

    const drawing_rectangle: rl.Rectangle = .{ .x = screenWidth / 2, .y = screenHeight / 2, .height = 140, .width = 100 };

    //SETUP THE RECTANGLES FOR EACH PLAYER
    while (!rl.windowShouldClose()) {
        //    const input = try stream_in.takeDelimiterExclusive('\n');
        //   std.debug.print("READ INPUT: {s}\n", .{input});

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        rl.drawTexture(background_texture, 0, 0, .white);
        rl.drawTexturePro(card_back_texture, .{ .x = 0, .y = 0, .width = @floatFromInt(card_back_texture.width), .height = @floatFromInt(card_back_texture.height) }, drawing_rectangle, .{ .y = drawing_rectangle.height / 2.0, .x = drawing_rectangle.width / 2.0 }, 0, .white);
        blackjack();

        rl.drawText("Congrats! You Created your first window!", 190, 200, 20, .light_gray);
    }
}

pub fn blackjack() void {

    //
    rl.drawLine(0, (screenHeight / 4) * 1, screenWidth, (screenHeight / 4) * 1, .red);
    rl.drawLine(0, (screenHeight / 4) * 2, screenWidth, (screenHeight / 4) * 2, .red);
    rl.drawLine(0, (screenHeight / 4) * 3, screenWidth, (screenHeight / 4) * 3, .red);

    //first verticle
    rl.drawLine(screenWidth / 8, 0, screenWidth / 8, screenHeight, .red);

    //player 1
    rl.drawLine((screenWidth / 8) * 2, screenHeight, 0, (screenHeight / 4) * 2, .red);
    rl.drawLine((screenWidth / 8) * 2, 0, (screenWidth / 8) * 2, screenHeight, .red);

    rl.drawLine((screenWidth / 8) * 3, 0, (screenWidth / 8) * 3, screenHeight, .red);
    rl.drawLine((screenWidth / 8) * 3, screenHeight, 0, (screenHeight / 4) * 1, .red);

    rl.drawLine((screenWidth / 8) * 4, 0, (screenWidth / 8) * 4, screenHeight, .red);
    rl.drawLine((screenWidth / 8) * 4, screenHeight, 0, 0, .red);

    rl.drawLine((screenWidth / 8) * 5, 0, (screenWidth / 8) * 5, screenHeight, .red);
    rl.drawLine((screenWidth / 8) * 5, screenHeight, screenWidth / 8, 0, .red);

    rl.drawLine((screenWidth / 8) * 6, 0, (screenWidth / 8) * 6, screenHeight, .red);
    rl.drawLine((screenWidth / 8) * 6, screenHeight, (screenWidth / 8) * 2, 0, .red);

    rl.drawLine((screenWidth / 8) * 7, 0, (screenWidth / 8) * 7, screenHeight, .red);
    rl.drawLine((screenWidth / 8) * 7, screenHeight, (screenWidth / 8) * 3, 0, .red);
}

pub fn manageConnection(stream: *std.net.Stream, address: *std.net.Address) !void {
    stream.* = try std.net.tcpConnectToAddress(address.*);
}
