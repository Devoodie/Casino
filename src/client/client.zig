const std = @import("std");
const rl = @import("raylib");
const protocol = @import("protocol");
const deck_utils = protocol.deck_utils;

var signedScreenWidth: i32 = undefined;
var signedScreenHeight: i32 = undefined;

var screenWidth: f32 = undefined;
var screenHeight: f32 = undefined;

var card_back_texture: rl.Texture2D = undefined;

var gamestate: protocol.Gamestate = undefined;

pub fn main() !void {
    //1280
    //720

    //sample gamestate data
    rl.initWindow(0, 0, "Dev's Casino");

    // signedScreenWidth = @divTrunc((rl.getScreenWidth() * 2), 3);
    // signedScreenHeight = @divTrunc((rl.getScreenHeight() * 2), 3);

    signedScreenWidth = 1280;
    signedScreenHeight = 720;

    screenWidth = @floatFromInt(signedScreenWidth);
    screenHeight = @floatFromInt(signedScreenHeight);

    rl.setWindowSize(signedScreenWidth, signedScreenHeight);

    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);
    //make a connection thread

    var server_address = try std.net.Address.parseIp4("127.0.0.1", 8192);
    var connection_stream: std.net.Stream = undefined;

    var connection_thread = try std.Thread.spawn(.{}, manageConnection, .{ &connection_stream, &server_address, &gamestate });
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
    //initalize game
    var alloc_config = std.heap.DebugAllocator(.{}).init;
    const allocator = alloc_config.allocator();

    gamestate = .{
        .bets = try allocator.alloc(?f32, 7),
        .chips = try allocator.alloc(?f32, 7),
        .ids = try allocator.alloc(?u16, 7),
        .hands = try allocator.alloc(?std.ArrayList(std.ArrayList(deck_utils.cards)), 7),
        .hand_value = try allocator.alloc(?std.ArrayList(?u8), 7),
    };

    const background_image = try rl.loadImage("assets/green_texture.jpg");
    const background_texture = try rl.loadTextureFromImage(background_image);

    const card_back = try rl.loadImage("assets/bicycle-130/card_back.jpg");
    card_back_texture = try rl.loadTextureFromImage(card_back);

    var drawing_rectangle: rl.Rectangle = .{ .x = screenWidth / 2, .y = screenHeight / 2, .height = (screenWidth / 16) * 1.4, .width = screenWidth / 16 };

    const player_starting_positions: []const rl.Vector2 = &.{
        .{ .x = (screenWidth / 2), .y = screenHeight / 8 },
        .{ .x = (screenWidth / 16), .y = (screenHeight / 8) * 4 },
        .{ .x = (screenWidth / 16) * 3, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 7, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 11, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 15, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 15, .y = (screenHeight / 8) * 4 },
    };

    var player_hand_positions = [7]std.ArrayList(?std.ArrayList(rl.Vector2)){
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
    };

    for (player_starting_positions, &player_hand_positions) |starting_position, *hand_positions| {
        //initialize each player with the possibility of 3 hands
        hand_positions.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);
        //append hand positions array
        try hand_positions.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
        try hand_positions.items[0].?.append(allocator, starting_position);
    }

    //intialize test card values
    //for player
    for (gamestate.hands) |*player| {
        //initialize player
        //append a hand to the player
        //append card to hand
        player.* = try std.ArrayList(std.ArrayList(deck_utils.cards)).initCapacity(allocator, 3);
        try player.*.?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 4));
        try player.*.?.items[0].append(allocator, deck_utils.cards.SPADE_KING);
    }

    defer {
        for (&player_hand_positions) |*position| {
            position.deinit(allocator);
        }
    }

    while (!rl.windowShouldClose()) {
        //    const input = try stream_in.takeDelimiterExclusive('\n');
        //   std.debug.print("READ INPUT: {s}\n", .{input});

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        //SETUP THE RECTANGLES FOR EACH PLAYER

        rl.drawTexture(background_texture, 0, 0, .white);

        const screenHeightDivision = @divFloor(signedScreenHeight, 4);
        const screenWidthDivision = @divFloor(signedScreenWidth, 8);

        rl.drawLine(0, screenHeightDivision * 1, signedScreenWidth, screenHeightDivision * 1, .red);
        rl.drawLine(0, screenHeightDivision * 2, signedScreenWidth, screenHeightDivision * 2, .red);
        rl.drawLine(0, screenHeightDivision * 3, signedScreenWidth, screenHeightDivision * 3, .red);

        // //first verticle
        rl.drawLine(screenWidthDivision, 0, screenWidthDivision, signedScreenHeight, .red);
        // //player 1
        rl.drawLine(screenWidthDivision * 2, signedScreenHeight, 0, screenHeightDivision * 2, .red);
        rl.drawLine(screenWidthDivision * 2, 0, screenWidthDivision * 2, signedScreenHeight, .red);
        //
        rl.drawLine(screenWidthDivision * 3, 0, screenWidthDivision * 3, signedScreenHeight, .red);
        rl.drawLine(screenWidthDivision * 3, signedScreenHeight, 0, screenHeightDivision * 1, .red);
        //
        rl.drawLine(screenWidthDivision * 4, 0, screenWidthDivision * 4, signedScreenHeight, .red);
        rl.drawLine(screenWidthDivision * 4, signedScreenHeight, 0, 0, .red);
        //
        rl.drawLine(screenWidthDivision * 5, 0, screenWidthDivision * 5, signedScreenHeight, .red);
        rl.drawLine(screenWidthDivision * 5, signedScreenHeight, screenWidthDivision, 0, .red);
        //
        rl.drawLine(screenWidthDivision * 6, 0, screenWidthDivision * 6, signedScreenHeight, .red);
        rl.drawLine(screenWidthDivision * 6, signedScreenHeight, screenWidthDivision * 2, 0, .red);
        //
        rl.drawLine(screenWidthDivision * 7, 0, screenWidthDivision * 7, signedScreenHeight, .red);
        rl.drawLine(screenWidthDivision * 7, signedScreenHeight, screenWidthDivision * 3, 0, .red);
        //
        // rl.drawText("Congrats! You Created your first window!", 190, 200, 20, .light_gray);

        try renderCards(player_hand_positions[0..player_hand_positions.len], &drawing_rectangle);
    }
}

// this needs to strictly render cards according to position
// 3Dimensions of iteration
pub fn renderCards(
    player_hand_positions: []std.ArrayList(?std.ArrayList(rl.Vector2)),
    rectangle_pointer: *rl.Rectangle,
) !void {
    //CARD OFFSET
    //WIDTH 32
    //HEIGHT 8
    var drawing_rectangle = rectangle_pointer.*;
    const player_cards = gamestate.hands;

    //right now this just iterates over positions but lets try to have it iterate over cards too
    //for player

    //    var card_texture: rl.Texture2D = undefined;
    for (player_hand_positions, 0..) |player_hand, player_index| {
        if (player_cards[player_index] == null) continue;
        //for each player hand

        for (player_hand.items, player_cards[player_index].?.items) |hand_position, hand_cards| {
            if (hand_position == null) continue;
            for (hand_position.?.items, hand_cards.items) |card_position, card_value| {
                //card_texture = getCardTexture(card_value);
                _ = card_value;
                drawing_rectangle.x = card_position.x;
                drawing_rectangle.y = card_position.y;

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
    }
}

// pub fn getCardTexture(card: deck_utils.cards) !rl.Vector2 {
//     _ = void;
// }

pub fn manageConnection(stream: *std.net.Stream, address: *std.net.Address, state: *protocol.Gamestate) !void {
    _ = state;
    stream.* = try std.net.tcpConnectToAddress(address.*);
}
