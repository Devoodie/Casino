const std = @import("std");
const rl = @import("raylib");
const protocol = @import("src/protocol.zig");
const screenWidth = 1280;
const screenHeight = 720;

var gamestate: protocol.Gamestate = undefined;
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

    try blackjack();

    //   var read_buffer: [4096]u8 = undefined;
    //  var write_buffer: [4096]u8 = undefined;

    //  var stream_reader = connection_stream.reader(&read_buffer);
    //    var stream_writer = connection_stream.writer(&write_buffer);

    // var stream_in = &stream_reader.file_reader.interface;
    //   var stream_out = &stream_writer.interface;
}

pub fn blackjack() !void {
    const background_image = try rl.loadImage("assets/green_texture.jpg");
    const background_texture = try rl.loadTextureFromImage(background_image);

    const card_back = try rl.loadImage("assets/bicycle-130/card_back.jpg");
    const card_back_texture = try rl.loadTextureFromImage(card_back);

    var drawing_rectangle: rl.Rectangle = .{ .x = screenWidth / 2, .y = screenHeight / 2, .height = (screenWidth / 16) * 1.4, .width = screenWidth / 16 };

    const player_positions = [_]rl.Vector2{
        .{ .x = (screenWidth / 2), .y = screenHeight / 8 },
        .{ .x = (screenWidth / 16) * 3, .y = (screenHeight * 7) / 8 },
        .{ .x = (screenWidth / 16) * 7, .y = (screenHeight * 7) / 8 },
        .{ .x = (screenWidth / 16) * 11, .y = (screenHeight * 7) / 8 },
        .{ .x = (screenWidth / 16) * 15, .y = (screenHeight * 7) / 8 },
    };

    while (!rl.windowShouldClose()) {
        //    const input = try stream_in.takeDelimiterExclusive('\n');
        //   std.debug.print("READ INPUT: {s}\n", .{input});

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        //SETUP THE RECTANGLES FOR EACH PLAYER

        rl.drawTexture(background_texture, 0, 0, .white);

        for (player_positions) |position| {
            drawing_rectangle.x = position.x;
            drawing_rectangle.y = position.y;

            rl.drawTexturePro(
                card_back_texture,
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(card_back_texture.width),
                    .height = @floatFromInt(card_back_texture.height),
                },
                drawing_rectangle,
                .{ .y = drawing_rectangle.height / 2.0, .x = drawing_rectangle.width / 2.0 },
                0,
                .white,
            );
        }

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

        rl.drawText("Congrats! You Created your first window!", 190, 200, 20, .light_gray);

        drawing_rectangle.x = player_positions[1].x - screenWidth / 32;
        drawing_rectangle.y = player_positions[1].y - screenHeight / 8;

        rl.drawTexturePro(
            card_back_texture,
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(card_back_texture.width),
                .height = @floatFromInt(card_back_texture.height),
            },
            drawing_rectangle,
            .{ .y = drawing_rectangle.height / 2.0, .x = drawing_rectangle.width / 2.0 },
            0,
            .white,
        );

        drawing_rectangle.x = player_positions[2].x - screenWidth / 32;
        drawing_rectangle.y = player_positions[2].y - screenHeight / 8;

        rl.drawTexturePro(
            card_back_texture,
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(card_back_texture.width),
                .height = @floatFromInt(card_back_texture.height),
            },
            drawing_rectangle,
            .{ .y = drawing_rectangle.height / 2.0, .x = drawing_rectangle.width / 2.0 },
            0,
            .white,
        );
    }
}

pub fn renderCards() !void {}

pub fn manageConnection(stream: *std.net.Stream, address: *std.net.Address, state: *protocol.Gamestate) !void {
    _ = state;
    stream.* = try std.net.tcpConnectToAddress(address.*);
}
