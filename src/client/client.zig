const std = @import("std");
const assets = @import("assets.zig");
const protocol = @import("protocol");
const deck_utils = @import("deck_utils");

const rl = @import("raylib");

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

    try assets.loadCardTextures();

    const background_image = try rl.loadImage("assets/green_texture.jpg");
    const background_texture = try rl.loadTextureFromImage(background_image);

    const card_back = try rl.loadImage("assets/bicycle-130/card_back.jpg");
    card_back_texture = try rl.loadTextureFromImage(card_back);

    var drawing_rectangle: rl.Rectangle = .{ .x = screenWidth / 2, .y = screenHeight / 2, .height = ((screenWidth / 16) * 1.4) * 1.35, .width = (screenWidth / 16) * 1.35 };

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

    var target_hand_positions = [7]std.ArrayList(?std.ArrayList(rl.Vector2)){
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
    };

    var transformation_vectors = [7]std.ArrayList(?std.ArrayList(rl.Vector2)){
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
    };

    //this is going to be a struggle because im getting zero lsp support on this
    const positional_arrays: blackjack_positional_array = .{
        .player_starting_positions = player_starting_positions,
        .card_positions = &player_hand_positions,
        .target_card_positions = &target_hand_positions,
        .transformation_vectors = &transformation_vectors,
    };

    for (player_starting_positions, &player_hand_positions, &target_hand_positions, &transformation_vectors) |starting_position, *hand_positions, *target_positions, *transformations| {
        //initialize each player with the possibility of 3 hands
        hand_positions.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);
        target_positions.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);
        transformations.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);

        //append hand positions array
        try hand_positions.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
        try hand_positions.items[0].?.append(allocator, .{ .x = (screenWidth / 8) * 3, .y = (screenHeight / 8) });

        try target_positions.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
        try target_positions.items[0].?.append(allocator, starting_position);

        try transformations.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
        try transformations.*.items[0].?.append(allocator, .{ .x = 0, .y = 0 });
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

    gamestate.hands[1].?.items[0].appendAssumeCapacity(deck_utils.cards.SPADE_ACE);
    positional_arrays.target_card_positions[1].items[0].?.appendAssumeCapacity(.{
        .x = player_starting_positions[1].x + 16.0,
        .y = player_starting_positions[1].y - 64.0,
    });
    positional_arrays.card_positions[1].items[0].?.appendAssumeCapacity(.{ .x = (screenWidth / 8) * 3, .y = (screenHeight / 8) });
    positional_arrays.transformation_vectors[1].items[0].?.appendAssumeCapacity(.{ .x = 0, .y = 0 });

    defer {
        for (&player_hand_positions) |*position| {
            position.deinit(allocator);
        }
    }

    while (!rl.windowShouldClose()) {
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
        //

        for (
            positional_arrays.card_positions,
            positional_arrays.target_card_positions,
            positional_arrays.transformation_vectors,
        ) |player_pos, player_desired, player_trans| {
            for (player_pos.items, player_desired.items, player_trans.items) |deck_pos, deck_desired, deck_trans| {
                if (deck_desired == null) continue;
                calcTransforms(deck_pos.?.items, deck_desired.?.items, deck_trans.?.items);
                moveCards(deck_pos.?.items, deck_trans.?.items);
            }
        }
        renderDeck(0, &drawing_rectangle);

        try renderCards(positional_arrays.card_positions, &drawing_rectangle);
    }
}

// MAKE THESE GENERIC SO THAT THEY ARE RESUABLE FOR OTHER GAMES
pub fn calcTransforms(
    card_positions: []rl.Vector2,
    desired_positions: []rl.Vector2,
    trans_vectors: []rl.Vector2,
) void {
    //add a desync modifier for lag
    var signed_bit: f32 = 1;
    for (card_positions, desired_positions, trans_vectors) |card_position, desired_position, *trans_vector| {
        const x_eql = std.math.approxEqRel(f32, card_position.x, desired_position.x, 0.01);
        const y_eql = std.math.approxEqRel(f32, card_position.y, desired_position.y, 0.01);

        if (x_eql and y_eql) {
            continue;
        }
        if (@abs(desired_position.x - card_position.x) < 10) {
            trans_vector.x = desired_position.x - card_position.x;
        } else {
            if (card_position.x > desired_position.x) signed_bit = -1;
            //WORK HERE
            trans_vector.x += 10 * signed_bit;
            signed_bit = 1;
        }
        if (@abs(desired_position.y - card_position.y) < 10) {
            trans_vector.y = desired_position.y - card_position.y;
        } else {
            if (card_position.y > desired_position.y) signed_bit = -1;
            trans_vector.y += 10 * signed_bit;
            signed_bit = 1;
        }
    }
}

// just moves cards based on their respective transformation vectors and resets them
pub fn moveCards(card_positions: []rl.Vector2, trans_vectors: []rl.Vector2) void {
    for (card_positions, trans_vectors, 0..) |*card_position, *vector, i| {
        _ = i;
        card_position.* = rl.math.vector2Add(card_position.*, vector.*);
        vector.* = .{ .x = 0, .y = 0 };
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

    var card_texture: rl.Texture2D = undefined;
    for (player_hand_positions, 0..) |player_hand, player_index| {
        if (player_cards[player_index] == null) continue;
        //for each player hand

        for (player_hand.items, player_cards[player_index].?.items) |hand_position, hand_cards| {
            if (hand_position == null) continue;
            for (hand_position.?.items, hand_cards.items) |card_position, card_value| {
                card_texture = assets.card_textures[@intFromEnum(card_value)];
                drawing_rectangle.x = card_position.x;
                drawing_rectangle.y = card_position.y;

                rl.drawTexturePro(
                    card_texture,
                    .{
                        .x = 0,
                        .y = 0,
                        .width = @floatFromInt(card_texture.width),
                        .height = @floatFromInt(card_texture.height),
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

pub fn renderDeck(game: u8, rectangle_pointer: *rl.Rectangle) void {
    var drawing_rectangle = rectangle_pointer.*;
    if (game == 0) {
        drawing_rectangle.x = (screenWidth / 8) * 3;
        drawing_rectangle.y = (screenHeight / 8);
    }

    for (0..52) |_| {
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
        drawing_rectangle.y -= 0.25;
    }
}

pub fn manageConnection(stream: *std.net.Stream, address: *std.net.Address, state: *protocol.Gamestate) !void {
    _ = state;
    stream.* = try std.net.tcpConnectToAddress(address.*);
}

const GAME = enum {
    BLACKJACK,
};

const Animations = enum {
    DEALING,
};

const blackjack_positional_array = struct {
    player_starting_positions: []const rl.Vector2,
    card_positions: []std.ArrayList(?std.ArrayList(rl.Vector2)),
    target_card_positions: []std.ArrayList(?std.ArrayList(rl.Vector2)),
    transformation_vectors: []std.ArrayList(?std.ArrayList(rl.Vector2)),
};
