const std = @import("std");
const deck_utils = @import("decks.zig");
const protocol = @import("protocol.zig");

var stdout: *std.Io.Writer = undefined;
var stderr: *std.Io.Writer = undefined;
var stdin: *std.Io.Reader = undefined;

var address: std.net.Address = undefined;

pub fn blackjack(allocator: std.mem.Allocator) !void {
    var out_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&out_buffer);
    stdout = &stdout_writer.interface;

    var err_buffer: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stdout().writer(&err_buffer);
    stderr = &stderr_writer.interface;

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    stdin = &stdin_reader.interface;

    //
    try stdout.print("Initializing Network!\n", .{});

    // connections need to be on the heap
    // connections array needs to be an array of poiners
    try stdout.print("Initalizing Blackjack!\n", .{});
    try stdout.flush();

    var deck = try std.ArrayList(deck_utils.cards).initCapacity(allocator, 52);
    defer deck.deinit(allocator);

    var spent_deck = try std.ArrayList(deck_utils.cards).initCapacity(allocator, 52);
    defer spent_deck.deinit(allocator);

    try deck_utils.initialize_deck(allocator, &deck, 8);

    //struct of arrays miht be fucking me here
    //*apparently this is array of struct of arrays*
    const connections = try allocator.alloc(?std.net.Server.Connection, 7);
    const ids = try allocator.alloc(?u16, 7);
    const chips = try allocator.alloc(?f32, 7);
    const hand_value = try allocator.alloc(?std.ArrayList(?u8), 7);
    const bets = try allocator.alloc(?f32, 7);
    const hands = try allocator.alloc(?std.ArrayList(?std.ArrayList(deck_utils.cards)), 7);

    //struct neeeded
    //first array is a slice of arraylists with a length of 7
    //2nd array is an arraylist which containts a hand arraylist!!!!
    //3rd array is an arraylist of which can be null

    defer allocator.free(connections);
    defer allocator.free(ids);
    defer allocator.free(chips);
    defer allocator.free(hand_value);
    defer allocator.free(bets);
    defer allocator.free(hands);

    var gamestate = try allocator.create(protocol.Gamestate);
    defer allocator.destroy(gamestate);

    //initalize all values to null instead of undefined
    for (connections, ids, chips, hand_value, bets, hands) |*connection, *id, *total_chips, *value, *bet, *hand| {
        connection.* = null;
        id.* = null;
        total_chips.* = null;
        value.* = null;
        bet.* = null;
        hand.* = null;
    }

    gamestate.ids = ids;
    gamestate.chips = chips;
    gamestate.hand_value = hand_value;
    gamestate.bets = bets;
    gamestate.hands = hands;

    address = try std.net.Address.parseIp4("0.0.0.0", 8192);

    ids[0] = 0;
    chips[0] = null;

    ids[1] = 1;
    chips[1] = 1000;

    //dealer always has id 0
    //fucking 3-dimensional array my guy
    hands[0] = try std.ArrayList(?std.ArrayList(deck_utils.cards)).initCapacity(allocator, 0);
    hands[1] = try std.ArrayList(?std.ArrayList(deck_utils.cards)).initCapacity(allocator, 0);

    hand_value[0] = try std.ArrayList(?u8).initCapacity(allocator, 1);
    hand_value[1] = try std.ArrayList(?u8).initCapacity(allocator, 1);

    try hands[0].?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 0));
    try hands[1].?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 0));

    try stdout.flush();

    var connection_thread = try std.Thread.spawn(.{}, protocol.acceptConnections, .{ &address, connections, gamestate });
    //var handling_thread = try std.Thread.spawn(.{}, protocol.sendGameState, .{ connections, gamestate.* });

    defer connection_thread.join();
    //defer handling_thread.join();

    var dealt_card: deck_utils.cards = undefined;
    while (true) {
        const dealer_hand = &hands[0].?.items[0].?;
        //one iteration represents a round

        if (deck.items.len <= 52) {
            try stdout.print("\n\nNEW SHOE!\n", .{});
            while (spent_deck.pop()) |card| {
                try deck.append(allocator, card);
            }
        }

        try stdout.print("\n\nNew Hand!\n", .{});

        try stdout.print("\n\nBETS BETS BETS!\n", .{});

        for (1..7) |i| {
            //change this section for connectivity
            if (ids[i] == null or i == 0) continue;
            try process_bets_blackjack(&bets[i], &chips[i]);
        }

        //deal cards
        for (0..14) |i| {
            if (ids[i % 7] == null) continue;
            dealt_card = deck.pop().?;
            try spent_deck.append(allocator, dealt_card);
            try hands[i % 7].?.items[0].?.append(allocator, dealt_card);
        }

        //need to remember to shrink and free hand values
        defer free_cards: {
            //EDIT HERE FOR SPLITTING
            for (hands, hand_value) |*player_hands, *value| {
                if (player_hands.* == null) continue;
                player_hands.*.?.shrinkAndFree(allocator, 1);
                value.*.?.clearAndFree(allocator);
                player_hands.*.?.items[0].?.clearAndFree(allocator);
            }
            break :free_cards;
        }

        //check for blackjack
        for (hands, 0..) |hand, seat| {
            if (hand == null) continue;
            for (hand.?.items) |*cards| {
                if (cards.* == null) continue;
                var value: u8 = 0;
                var total: u8 = 0;
                for (cards.*.?.items) |card| {
                    value = blackjack_card_value(card);
                    total += value;
                }
                try hand_value[seat].?.append(allocator, total);
            }
        }

        try protocol.sendGameState(connections, gamestate.*);

        try show_all_cards_blackjack(hands, 0);
        try stdout.flush();

        //figure out the best way to skip input parsing for blackjacks

        for (1..8) |i| {
            const seat = i % 7;
            const id = ids[seat];

            if (hand_value[0].?.items[0] == 21) {
                try stdout.print("DEALER BLACKJACK!\nCARDS: ", .{});
                for (dealer_hand.items) |card| {
                    try stdout.print("{any} ", .{card});
                }
                try stdout.print("|\n", .{});
                break;
            }
            if (id == null) continue;

            switch (id.?) {
                0 => dealer: {
                    var value: u8 = 0;
                    var total: u8 = 0;
                    var ace_count: u8 = 0;

                    try stdout.print("DEALER CARDS: ", .{});
                    for (dealer_hand.items) |card| {
                        value = blackjack_card_value(card);
                        try stdout.print("{any} ", .{card});
                        if (value == 11) {
                            ace_count += 1;
                        }
                        total += value;
                    }
                    try stdout.print("\n", .{});
                    while (total < 17) {
                        dealt_card = deck.pop().?;
                        try spent_deck.append(allocator, dealt_card);
                        try dealer_hand.append(allocator, dealt_card);
                        value = blackjack_card_value(dealt_card);
                        if (value == 11) {
                            ace_count += 1;
                        }
                        total += value;
                        try stdout.print("DEALER HIT!\nCARD: {any}\n", .{dealt_card});
                        if (total >= 17 and ace_count > 0) {
                            total -= 10;
                            ace_count -= 1;
                        }
                    }
                    try stdout.print("DEALER TOTAL: {d}\n", .{total});
                    hand_value[0].?.items[0] = total;
                    break :dealer;
                },
                1 => {
                    if (hand_value[seat].?.items[0] == 21) {
                        try stdout.print("SEAT {d} BLACKJACK!!!\n", .{seat});
                        const earnings = bets[seat].? * 2.5;
                        try stdout.print("EARNINGS: {d:.2}\n", .{earnings});
                        chips[seat].? += earnings;
                        try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}\n", .{ seat, chips[seat].? });
                        hand_value[seat] = null;
                        continue;
                    }
                    try stdout.print("\n", .{});
                    try process_blackjack_input(allocator, &deck, &spent_deck, hands, @truncate(i), &hand_value[i].?, &chips[i], &bets[i]);
                    try stdout.print("\n", .{});
                },
                else => {
                    std.debug.print("Unknown error has occured!\n", .{});
                },
            }
            try protocol.sendGameState(connections, gamestate.*);
        }
        try stdout.print("\n\n", .{});

        //processes the winnings
        const dealer_value = hand_value[0].?.items[0].?;
        for (hand_value, chips, 0..) |hand_values, *pot, i| {
            if (hand_values == null or i == 0) continue;
            for (hand_values.?.items) |value| {
                if (value == null or i == 0) continue;
                if ((value.? < dealer_value and dealer_value < 22) or value.? > 21) {
                    try stdout.print("SEAT: {d} LOSES!\n", .{i});
                    try stdout.print("SEAT {d} BET: {d:.2}\n", .{ i, bets[i].? });
                    try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}", .{ i, pot.*.? });
                } else if (value.? > dealer_value or dealer_value > 21) {
                    try stdout.print("SEAT: {d} WINS!\n", .{i});
                    try stdout.print("SEAT {d} BET: {d:.2}\n", .{ i, bets[i].? });

                    const earnings = bets[i].? * 2;
                    try stdout.print("EARNINGS: {d:.2}\n", .{bets[i].?});
                    pot.*.? += earnings;

                    try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}\n", .{ i, pot.*.? });
                } else {
                    try stdout.print("SEAT: {d} PUSHES!\n", .{i});
                    pot.*.? += bets[i].?;
                    try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}\n", .{ i, pot.*.? });
                }
            }
        }
        try stdout.flush();
    }
}

fn process_blackjack_input(
    allocator: std.mem.Allocator,
    deck: *std.ArrayList(deck_utils.cards),
    spent_deck: *std.ArrayList(deck_utils.cards),
    hands: []?std.ArrayList(?std.ArrayList(deck_utils.cards)),
    seat: u8,
    hand_value: *std.ArrayList(?u8),
    chips: *?f32,
    bet: *?f32,
) !void {
    var dealt_card: deck_utils.cards = undefined;
    var buffer: [4096]u8 = undefined;
    var first_iteration = true;
    var hand_iterator: u8 = 0;

    while (stdin.takeDelimiterExclusive('\n')) |raw| {
        //        _ = try stdin.discardShort(1);
        try stdout.flush();
        const input = std.ascii.lowerString(&buffer, raw);
        if (std.mem.eql(u8, input, "hit")) {
            first_iteration = false;
            dealt_card = deck.pop().?;
            const player_deck = &hands[seat].?.items[hand_iterator].?;

            try player_deck.*.append(allocator, dealt_card);
            try spent_deck.*.append(allocator, dealt_card);

            try stdout.print("HITTING\nNEWCARD: {any}\n", .{dealt_card});
            var total: u8 = 0;
            var value: u8 = 0;
            var ace_count: u8 = 0;

            for (player_deck.items) |card| {
                value = blackjack_card_value(card);
                if (value == 11) {
                    ace_count += 1;
                }
                total += value;
            }

            if (total > 21) {
                while (total > 21 and ace_count > 0) {
                    total -= 10;
                    ace_count -= 1;
                }
                if (total < 21) {
                    hand_value.*.items[hand_iterator] = total;
                    try stdout.print("TOTAL: {d}\n", .{total});
                    continue;
                }
                hand_value.*.items[hand_iterator] = total;
                try stdout.print("TOTAL: {d}\n", .{total});
                try stdout.print("BUSTED!\n", .{});

                if (hand_iterator == hands[seat].?.items.len - 1) {
                    break;
                } else {
                    hand_iterator += 1;
                    continue;
                }
            } else if (total < 21) {
                hand_value.*.items[hand_iterator] = total;
                try stdout.print("TOTAL: {d}\n", .{total});
                continue;
            } else {
                hand_value.*.items[hand_iterator] = total;
                try stdout.print("TOTAL: {d}\n", .{total});

                if (hand_iterator == hands[seat].?.items.len - 1) {
                    break;
                } else {
                    hand_iterator += 1;
                    continue;
                }
            }
        } else if (std.mem.eql(u8, input, "stand") or std.mem.eql(u8, input, "stay")) {
            //            var value: u8 = 0;
            try stdout.print("STANDING! CARDS: ", .{});
            const player_deck = &hands[seat].?.items[hand_iterator].?;
            for (player_deck.items) |card| {
                try stdout.print("{any} ", .{card});
            }

            try stdout.print("\nTOTAL: {d}\n", .{hand_value.items[hand_iterator].?});

            if (hand_iterator == hands[seat].?.items.len - 1) {
                break;
            } else {
                hand_iterator += 1;
                continue;
            }
        } else if (std.mem.eql(u8, input, "show cards") or std.mem.eql(u8, input, "show")) {
            try show_all_cards_blackjack(hands, 1);
        } else if (std.mem.eql(u8, input, "double")) {
            if (first_iteration != true) {
                try stdout.print("CAN'T DOUBLE AFTER HIT!\n", .{});
                continue;
            } else if (chips.*.? < bet.*.?) {
                try stdout.print("CAN'T DOUBLE WITH INSUFFICENT CHIPS:!\nCHIPS: {d}, BET: {d}\n", .{ chips.*.?, bet.*.? });
                continue;
            }

            chips.*.? -= bet.*.?;
            bet.*.? *= 2;

            var value: u8 = 0;
            var ace_count: u8 = 0;
            var total: u8 = 0;

            dealt_card = deck.pop().?;
            const player_deck = &hands[seat].?.items[hand_iterator].?;
            try player_deck.*.append(allocator, dealt_card);
            try spent_deck.*.append(allocator, dealt_card);

            try stdout.print("DOUBLING!!\nNEWCARD: {any}\n", .{dealt_card});

            for (player_deck.items) |card| {
                value = blackjack_card_value(card);
                if (value == 11) {
                    ace_count += 1;
                }
                total += value;
            }

            while (total > 21 and ace_count > 0) {
                total -= 10;
            }
            try stdout.print("TOTAL: {d}\n", .{total});

            hand_value.*.items[hand_iterator] = total;
            if (hand_iterator == hands[seat].?.items.len - 1) {
                break;
            } else {
                hand_iterator += 1;
                continue;
            }
        } else if (std.mem.eql(u8, input, "split")) {
            //split finna go crazy. (recursion maybe?)
            //recursion won't work for bet calculation
            //because we need to calculate it against the dealer at the end
            //multi dimensional array list is cancer but the only solution

            if (first_iteration != true) {
                try stdout.print("CAN'T SPLIT AFTER HIT!\n", .{});
                continue;
            }
            const player_deck = &hands[seat].?.items[hand_iterator].?;
            if (blackjack_card_value(player_deck.items[0]) != blackjack_card_value(player_deck.items[1])) {
                try stdout.print("CAN'T SPLIT TWO DIFFERENT CARD VALUES!\n{any} {any}\n", .{ player_deck.items[0], player_deck.items[1] });
                continue;
            }

            try stdout.print("SPLITTING:\n", .{});

            try hands[seat].?.append(allocator, try std.ArrayList(deck_utils.cards).initCapacity(allocator, 2));
            const new_hand = &hands[seat].?.items[hand_iterator + 1].?;

            new_hand.appendAssumeCapacity(player_deck.pop().?);

            //deal more cards

            dealt_card = deck.pop().?;

            try player_deck.append(allocator, dealt_card);
            try spent_deck.append(allocator, dealt_card);

            dealt_card = deck.pop().?;

            try new_hand.append(allocator, dealt_card);
            try spent_deck.append(allocator, dealt_card);

            try stdout.print("NEW CARDS:\n", .{});

            for (hands[seat].?.items, 1..) |hand, i| {
                try stdout.print("HAND {d}: ", .{i});
                for (hand.?.items) |card| {
                    try stdout.print("{any} ", .{card});
                }
                try stdout.print("|\n", .{});
            }
            first_iteration = true;
            hand_iterator += 1;
        } else if (std.mem.eql(u8, input, "exit")) {
            try stdout.print("EXITING!\n", .{});
            std.posix.exit(0);
            try stdout.flush();
        }
    } else |err| {
        return err;
    }
    try stdout.flush();
}

//pub fn split(hand: *std.ArrayList(deck_utils.cards), bet: *f32, chips: *f64) !void {
//}

pub fn show_all_cards_blackjack(hands: []?std.ArrayList(?std.ArrayList(deck_utils.cards)), player: u8) !void {
    for (hands, 0..) |player_hands, seat| {
        if (player_hands == null) continue;
        if (seat == 0) {
            try stdout.print("DEALER, ", .{});
        } else if (player == seat) {
            try stdout.print("*YOU* SEAT: {d}, ", .{seat});
        } else {
            try stdout.print("SEAT: {d}, ", .{seat});
        }

        for (player_hands.?.items, 1..) |hand, hand_num| {
            try stdout.print("HAND {d}: ", .{hand_num});

            for (hand.?.items, 0..) |card, i| {
                if (i == 0 and seat == 0) {
                    try stdout.print(".HIDDEN ", .{});
                    continue;
                }
                try stdout.print("{any} ", .{card});
            }

            try stdout.print("|\n", .{});
        }
    }
    //flush
}

pub fn blackjack_card_value(card: deck_utils.cards) u8 {
    switch (@intFromEnum(card) % 13) {
        0 => {
            return 2;
        },
        1 => {
            return 3;
        },
        2 => {
            return 4;
        },
        3 => {
            return 5;
        },
        4 => {
            return 6;
        },
        5 => {
            return 7;
        },
        6 => {
            return 8;
        },
        7 => {
            return 9;
        },
        8, 9, 10, 11 => {
            return 10;
        },
        12 => {
            return 11;
        },
        else => {
            std.debug.print("undefined error", .{});
            return 0;
        },
    }
}

pub fn process_bets_blackjack(
    bet: *?f32,
    chips: *?f32,
) !void {
    try stdout.print("Whats your bet!?\n", .{});
    try stdout.flush();

    var buffer: [4096]u8 = undefined;
    while (stdin.takeDelimiterExclusive('\n')) |raw| {
        //        _ = try stdin.discardShort(1);
        const input = std.ascii.lowerString(&buffer, raw);
        if (std.mem.eql(u8, input, "exit")) std.posix.exit(0);
        const float_input = std.fmt.parseFloat(f32, input) catch |err| {
            switch (err) {
                std.fmt.ParseFloatError.InvalidCharacter => {
                    try stdout.print("ERR: INVALID INTEGER!\n", .{});
                    try stdout.flush();
                    continue;
                },
            }
        };
        if (float_input <= chips.*.?) {
            bet.* = float_input;
            chips.*.? -= float_input;
            try stdout.print("CURRENT BET: {d:.2}\n", .{float_input});
            try stdout.print("REMAINING CHIPS: {d:.2}\n", .{chips.*.?});
            try stdout.flush();
            break;
        } else {
            try stdout.print("Bet Larger Than current chips: {d:.2}!\n", .{chips.*.?});
            try stdout.flush();
        }
    } else |err| {
        return err;
    }
}
