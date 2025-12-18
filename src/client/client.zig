const std = @import("std");
const assets = @import("assets.zig");
const protocol = @import("protocol");
const deck_utils = @import("deck_utils");
const Status = protocol.Status;

const rl = @import("raylib");

var signedScreenWidth: i32 = undefined;
var signedScreenHeight: i32 = undefined;

var screenWidth: f32 = undefined;
var screenHeight: f32 = undefined;

var card_back_texture: rl.Texture2D = undefined;

var gamestate: protocol.Gamestate = undefined;
var ani_status: Status = Status.DEALING;
var rendering_index: u16 = 0;

pub fn main() !void {
    //1280
    //720

    //sample gamestate data
    rl.initWindow(0, 0, "Dev's Casino");

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
        .hand_index = try allocator.alloc(?u8, 7),
        .player_turn = 1,
        .action = undefined,
    };

    gamestate.hand_index[1] = 0;

    try assets.loadCardTextures();

    const background_image = try rl.loadImage("assets/green_texture.jpg");
    const background_texture = try rl.loadTextureFromImage(background_image);

    const card_back = try rl.loadImage("assets/bicycle-130/card_back.jpg");
    card_back_texture = try rl.loadTextureFromImage(card_back);

    var drawing_rectangle: rl.Rectangle = .{ .x = screenWidth / 2, .y = screenHeight / 2, .height = ((screenWidth / 16) * 1.4) * 1.35, .width = (screenWidth / 16) * 1.35 };

    const player_starting_positions: []const rl.Vector2 = &.{
        .{ .x = (screenWidth / 2), .y = screenHeight / 8 },
        .{ .x = (screenWidth / 16) * 15, .y = (screenHeight / 8) * 4 },
        .{ .x = (screenWidth / 16) * 15, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 11, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 7, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16) * 3, .y = (screenHeight / 8) * 7 },
        .{ .x = (screenWidth / 16), .y = (screenHeight / 8) * 4 },
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

    var positional_arrays: blackjack_positional_array = .{
        .player_starting_positions = player_starting_positions,
        .card_positions = &player_hand_positions,
        .target_card_positions = &target_hand_positions,
        .transformation_vectors = &transformation_vectors,
    };

    for (&player_hand_positions, &target_hand_positions, &transformation_vectors) |*hand_positions, *target_positions, *transformations| {
        //initialize each player with the possibility of 3 hands
        hand_positions.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);
        target_positions.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);
        transformations.* = try std.ArrayList(?std.ArrayList(rl.Vector2)).initCapacity(allocator, 3);

        //append hand positions array
        try hand_positions.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
        //_ = starting_position;

        try target_positions.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));

        try transformations.*.append(allocator, try std.ArrayList(rl.Vector2).initCapacity(allocator, 4));
    }

    const rendered_cards: []?std.ArrayList(std.ArrayList(deck_utils.cards)) = try allocator.alloc(?std.ArrayList(std.ArrayList(deck_utils.cards)), 7);

    //intialize test card values
    //for player
    for (gamestate.hands, rendered_cards) |*player, *rendering| {
        //initialize player
        //append a hand to the player
        //append card to hand
        player.* = try std.ArrayList(std.ArrayList(deck_utils.cards)).initCapacity(allocator, 3);
        rendering.* = try std.ArrayList(std.ArrayList(deck_utils.cards)).initCapacity(allocator, 3);

        try player.*.?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 4));
        try rendering.*.?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 4));

        try player.*.?.items[0].append(allocator, deck_utils.cards.SPADE_KING);
        try player.*.?.items[0].append(allocator, deck_utils.cards.SPADE_QUEEN);
    }

    gamestate.hands[1].?.items[0].items[1] = deck_utils.cards.SPADE_ACE;

    defer {
        for (&player_hand_positions) |*position| {
            position.deinit(allocator);
        }
    }

    while (!rl.windowShouldClose()) {
        if (!rl.isWindowReady()) continue;
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

        try handleStatus(allocator, &positional_arrays, rendered_cards);

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

        for (positional_arrays.card_positions, rendered_cards) |hands, cards| {
            for (hands.items, cards.?.items) |hand_positions, hand_cards| {
                if (hand_positions == null) continue;
                try renderHand(hand_positions.?, hand_cards, &drawing_rectangle);
            }
        }
    }
}

//ASSERTIONS:
//positional arrays must be equal in length
//if an element is created or destroyed within the positional vectors, it must be reflected in all other arrays along with the renderin array
//a players cards must be equal to the amount of positions
pub fn handleStatus(
    allocator: std.mem.Allocator,
    positional_arrays: *blackjack_positional_array,
    rendered_cards: []?std.ArrayList(std.ArrayList(deck_utils.cards)),
) !void {
    switch (ani_status) {
        Status.DEALING => {
            //ensure that the first card is dealt
            dealCards(positional_arrays, rendered_cards);
        },
        Status.HIT => {
            //Make sure to DELETE THIS!!
            gamestate.hands[1].?.items[0].appendAssumeCapacity(deck_utils.cards.CLUB_FIVE);

            const player_index = gamestate.player_turn;
            const player = gamestate.hands[player_index].?;

            const hand_index = gamestate.hand_index[player_index].?;
            const hand_len = player.items[hand_index].items.len;
            const card = player.items[hand_index].items[hand_len - 1];

            //append to the rendered cards
            //
            const float_hand_len: f32 = @floatFromInt(hand_len - 1);
            var x_offset: f32 = -16.0 * float_hand_len;
            var y_offset: f32 = -64.0 * float_hand_len;

            if (player_index == 0) {
                x_offset = 16 * float_hand_len - 1;
                y_offset = 64 * float_hand_len - 1;
            } else if (player_index == 6) {
                x_offset = 16 * float_hand_len - 1;
                y_offset = -64 * float_hand_len - 1;
            }
            try rendered_cards[player_index].?.items[hand_index].append(allocator, card);

            positional_arrays.card_positions[player_index].items[hand_index].?.appendAssumeCapacity(.{
                .x = (screenWidth / 8) * 3,
                .y = (screenHeight / 8),
            });

            positional_arrays.target_card_positions[player_index].items[hand_index].?.appendAssumeCapacity(.{
                .x = positional_arrays.player_starting_positions[player_index].x + x_offset,
                .y = positional_arrays.player_starting_positions[player_index].y + y_offset,
            });
            positional_arrays.transformation_vectors[1].items[0].?.appendAssumeCapacity(.{
                .x = 0,
                .y = 0,
            });

            rendering_index += 1;
            ani_status = Status.ACTION;
        },
        Status.RESULT => {
            //add winning effects
        },
        Status.ACTION => {
            return;
        },
        else => {
            std.debug.print("NOT YET IMPLEMENTED\n", .{});
            return;
        },
    }
}

//find a way to make this reusable and generic
pub fn dealCards(positional_arrays: *blackjack_positional_array, rendered_cards: []?std.ArrayList(std.ArrayList(deck_utils.cards))) void {
    var comp_index: u16 = 0;
    //append first card
    if (rendered_cards[1].?.items[0].items.len == 0) {
        const first_card = gamestate.hands[1].?.items[0].items[0];
        rendered_cards[1].?.items[0].appendAssumeCapacity(first_card);
        positional_arrays.card_positions[1].items[0].?.appendAssumeCapacity(.{
            .x = (screenWidth / 8) * 3,
            .y = (screenHeight / 8),
        });
        positional_arrays.target_card_positions[1].items[0].?.appendAssumeCapacity(.{
            .x = positional_arrays.player_starting_positions[1].x,
            .y = positional_arrays.player_starting_positions[1].y,
        });
        positional_arrays.transformation_vectors[1].items[0].?.appendAssumeCapacity(.{
            .x = 0,
            .y = 0,
        });
    }
    var card_offset: u8 = 0;
    var signed_offset: f32 = 0;
    outer: for (1..15) |dividend| {
        if (dividend > 7) {
            card_offset = 1;
            signed_offset = 1;
        }
        const player_index = dividend % 7;

        if (gamestate.hands[player_index] == null) continue;
        if (comp_index == rendering_index) {
            const position = positional_arrays.card_positions[player_index].items[0].?.items[card_offset];
            const desired_position = positional_arrays.target_card_positions[player_index].items[0].?.items[card_offset];

            const x_eql = std.math.approxEqRel(f32, position.x, desired_position.x, 0.01);
            const y_eql = std.math.approxEqRel(f32, position.y, desired_position.y, 0.01);
            if (x_eql and y_eql) {
                //append next card, card position, and desired position
                var new_card: deck_utils.cards = undefined;
                if (dividend == 14) {
                    //make sure to DELETE THIS!
                    //                    ani_status = Status.RESULT;
                    ani_status = Status.HIT;
                    return;
                }
                if (dividend >= 7) {
                    card_offset = 1;
                    signed_offset = 1;
                }
                //find next available player and append their card
                for ((dividend + 1)..15) |j| {
                    if (gamestate.hands[j % 7] == null) {
                        continue;
                    } else {
                        new_card = gamestate.hands[j % 7].?.items[0].items[card_offset];
                        rendered_cards[j % 7].?.items[0].appendAssumeCapacity(new_card);
                        positional_arrays.card_positions[j % 7].items[0].?.appendAssumeCapacity(.{
                            .x = (screenWidth / 8) * 3,
                            .y = (screenHeight / 8),
                        });
                        if (dividend == 13) {
                            positional_arrays.target_card_positions[j % 7].items[0].?.appendAssumeCapacity(.{
                                .x = positional_arrays.player_starting_positions[j % 7].x + signed_offset * 16,
                                .y = positional_arrays.player_starting_positions[j % 7].y + signed_offset * 64,
                            });
                        } else if (dividend == 12) {
                            positional_arrays.target_card_positions[j % 7].items[0].?.appendAssumeCapacity(.{
                                .x = positional_arrays.player_starting_positions[j % 7].x + signed_offset * 16,
                                .y = positional_arrays.player_starting_positions[j % 7].y + signed_offset * -64,
                            });
                        } else {
                            positional_arrays.target_card_positions[j % 7].items[0].?.appendAssumeCapacity(.{
                                .x = positional_arrays.player_starting_positions[j % 7].x + signed_offset * -16,
                                .y = positional_arrays.player_starting_positions[j % 7].y + signed_offset * -64,
                            });
                        }
                        positional_arrays.transformation_vectors[j % 7].items[0].?.appendAssumeCapacity(.{
                            .x = 0,
                            .y = 0,
                        });

                        std.debug.assert(positional_arrays.target_card_positions[j % 7].items[0].?.items.len == positional_arrays.card_positions[j % 7].items[0].?.items.len);
                        std.debug.assert(rendered_cards[j % 7].?.items[0].items.len == positional_arrays.card_positions[j % 7].items[0].?.items.len);

                        rendering_index += 1;
                        break :outer;
                    }
                }
            } else {
                std.debug.assert(positional_arrays.target_card_positions[player_index].items[0].?.items.len == positional_arrays.card_positions[player_index].items[0].?.items.len);
                std.debug.assert(rendered_cards[player_index].?.items[0].items.len == positional_arrays.card_positions[player_index].items[0].?.items.len);
                break :outer;
            }
        }
        comp_index += 1;
    }
}

// MAKE THESE GENERIC SO THAT THEY ARE RESUABLE FOR OTHER GAMES
pub fn calcTransforms(
    card_positions: []rl.Vector2,
    desired_positions: []rl.Vector2,
    trans_vectors: []rl.Vector2,
) void {
    //add a desync modifier for lag
    for (card_positions, desired_positions, trans_vectors) |card_position, desired_position, *trans_vector| {
        const x_eql = std.math.approxEqRel(f32, card_position.x, desired_position.x, 0.01);
        const y_eql = std.math.approxEqRel(f32, card_position.y, desired_position.y, 0.01);

        if (x_eql and y_eql) {
            continue;
        }
        const buffer = rl.math.vector2MoveTowards(card_position, desired_position, 30.0);
        trans_vector.x = buffer.x - card_position.x;
        trans_vector.y = buffer.y - card_position.y;
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

// STRICTLY RENDERS A HAND
// 3Dimensions of iteration
// MAKE THIS GENERIC
pub fn renderHand(
    player_hand_positions: std.ArrayList(rl.Vector2),
    player_cards: std.ArrayList(deck_utils.cards),
    rectangle_pointer: *rl.Rectangle,
) !void {
    //CARD OFFSET
    //WIDTH 32
    //HEIGHT 8
    var drawing_rectangle = rectangle_pointer.*;

    var card_texture: rl.Texture2D = undefined;
    for (player_hand_positions.items, player_cards.items) |card_position, card| {
        card_texture = assets.card_textures[@intFromEnum(card)];
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

const blackjack_positional_array = struct {
    player_starting_positions: []const rl.Vector2,
    card_positions: []std.ArrayList(?std.ArrayList(rl.Vector2)),
    target_card_positions: []std.ArrayList(?std.ArrayList(rl.Vector2)),
    transformation_vectors: []std.ArrayList(?std.ArrayList(rl.Vector2)),
};
