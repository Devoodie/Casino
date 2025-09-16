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

    const connections = try allocator.alloc(?std.net.Server.Connection, 7);
    const ids = try allocator.alloc(?u16, 7);
    const chips = try allocator.alloc(?f64, 7);
    const hand_value = try allocator.alloc(?u8, 7);
    const bets = try allocator.alloc(?f64, 7);
    const hands = try allocator.alloc(?std.ArrayList(deck_utils.cards), 7);

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
    hands[0] = try std.ArrayList(deck_utils.cards).initCapacity(allocator, 0);
    hands[1] = try std.ArrayList(deck_utils.cards).initCapacity(allocator, 0);

    var connection_thread = try std.Thread.spawn(.{}, protocol.acceptConnections, .{ &address, connections, gamestate });
    var handling_thread = try std.Thread.spawn(.{}, protocol.sendGameState, .{connections});

    defer connection_thread.join();
    defer handling_thread.join();

    //    var index: u8 = 0;
    var dealt_card: deck_utils.cards = undefined;
    while (true) {
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
            try hands[i % 7].?.append(allocator, dealt_card);
        }

        defer free_cards: {
            for (hands) |*hand| {
                if (hand.* == null) continue;
                hand.*.?.clearAndFree(allocator);
            }
            break :free_cards;
        }
        //check for blackjack
        for (hands, 0..) |*cards, seat| {
            if (cards.* == null) continue;
            var value: u8 = 0;
            var total: u8 = 0;
            for (cards.*.?.items) |card| {
                value = blackjack_card_value(card);
                total += value;
            }
            hand_value[seat] = total;
        }

        try show_all_cards_blackjack(hands, 0);
        try stdout.flush();

        //figure out the best way to skip input parsing for blackjacks

        for (1..8) |i| {
            const seat = i % 7;
            const id = ids[seat];
            if (id == null) continue;
            switch (id.?) {
                0 => dealer: {
                    if (hand_value[0] == 21) {
                        try stdout.print("DEALER BLACKJACK!", .{});
                        break;
                    }
                    var value: u8 = 0;
                    var total: u8 = 0;
                    var ace_count: u8 = 0;

                    try stdout.print("DEALER CARDS: ", .{});
                    for (hands[0].?.items) |card| {
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
                        try hands[0].?.append(allocator, dealt_card);
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
                    hand_value[0] = total;
                    break :dealer;
                },
                1 => {
                    if (hand_value[seat] == 21) {
                        try stdout.print("SEAT {d} BLACKJACK!!!\n", .{seat});
                        const earnings = bets[seat].? * 2.5;
                        try stdout.print("EARNINGS: {d:.2}\n", .{earnings});
                        chips[seat].? += earnings;
                        try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}", .{ seat, chips[seat].? });
                        hand_value[seat] = null;
                        continue;
                    }
                    try stdout.print("\n", .{});
                    try process_blackjack_input(allocator, &deck, &spent_deck, hands, @truncate(i), &hand_value[i]);
                    try stdout.print("\n", .{});
                },
                else => {
                    std.debug.print("Unknown error has occured!\n", .{});
                },
            }
        }
        try stdout.print("\n\n", .{});
        for (chips, hand_value, 0..) |*pot, value, i| {
            if (value == null or i == 0) continue;
            if ((value.? < hand_value[0].? and hand_value[0].? < 22) or value.? > 21) {
                try stdout.print("SEAT: {d} LOSES!\n", .{i});
                try stdout.print("SEAT {d} BET: {d:.2}\n", .{ i, bets[i].? });
                try stdout.print("SEAT {d} TOTAL CHIPS: {d:.2}", .{ i, pot.*.? });
            } else if (value.? > hand_value[0].? or hand_value[0].? > 21) {
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
        try stdout.flush();
    }
}

fn process_blackjack_input(
    allocator: std.mem.Allocator,
    deck: *std.ArrayList(deck_utils.cards),
    spent_deck: *std.ArrayList(deck_utils.cards),
    hands: []?std.ArrayList(deck_utils.cards),
    seat: u8,
    hand_value: *?u8,
) !void {
    var dealt_card: deck_utils.cards = undefined;
    var buffer: [4096]u8 = undefined;
    while (stdin.takeDelimiterExclusive('\n')) |raw| {
        //        _ = try stdin.discardShort(1);
        //        std.debug.print("INPUT: {s}, INPUT LENGTH: {d}, BYTES DISCARDED: {d}", .{ input, input.len, bytes_discarded });
        const input = std.ascii.lowerString(&buffer, raw);
        if (std.mem.eql(u8, input, "hit")) {
            //im seeing stars
            dealt_card = deck.pop().?;
            const player_deck = &hands[seat].?;
            try player_deck.*.append(allocator, dealt_card);
            try spent_deck.*.append(allocator, dealt_card);
            try stdout.print("HITTING\nNEWCARD: {any}\n", .{dealt_card});
            var total: u8 = 0;
            var value: u8 = 0;
            var ace_count: u8 = 0;

            for (hands[seat].?.items) |card| {
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
                    hand_value.* = total;
                    try stdout.print("TOTAL: {d}\n", .{total});
                    continue;
                }
                hand_value.* = total;
                try stdout.print("TOTAL: {d}\n", .{total});
                try stdout.print("BUSTED!\n", .{});
                break;
            } else if (total < 21) {
                hand_value.* = total;
                try stdout.print("TOTAL: {d}\n", .{total});
                continue;
            } else {
                hand_value.* = total;
                try stdout.print("TOTAL: {d}\n", .{total});
                break;
            }
        } else if (std.mem.eql(u8, input, "stand") or std.mem.eql(u8, input, "stay")) {
            var total: u8 = 0;
            var value: u8 = 0;
            try stdout.print("STANDING! CARDS: ", .{});
            for (hands[seat].?.items) |card| {
                try stdout.print("{any} ", .{card});
                value = blackjack_card_value(card);
                if (value == 11 and total + value > 21) total += 1 else total += value;
            }
            hand_value.* = total;
            try stdout.print("\nTOTAL: {d}\n", .{total});
            break;
        } else if (std.mem.eql(u8, input, "exit")) {
            try stdout.print("EXITING!\n", .{});
            std.posix.exit(0);
        } else if (std.mem.eql(u8, input, "SHOW CARDS")) {
            try show_all_cards_blackjack(hands, 1);
        }
        try stdout.flush();
    } else |err| {
        return err;
    }
    try stdout.flush();
}

pub fn show_all_cards_blackjack(hands: []?std.ArrayList(deck_utils.cards), player: u8) !void {
    for (hands, 0..) |hand, seat| {
        if (hand == null) continue;
        if (seat == 0) {
            try stdout.print("DEALER, HAND: ", .{});
        } else if (player == seat) {
            try stdout.print("*YOU* SEAT: {d}, HAND: ", .{seat});
        } else {
            try stdout.print("SEAT: {d}, HAND: ", .{seat});
        }
        for (hand.?.items, 0..) |card, i| {
            if (i == 0 and seat == 0) {
                try stdout.print(".HIDDEN ", .{});
                continue;
            }
            try stdout.print("{any} ", .{card});
        }
        try stdout.print("|\n", .{});
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
    bet: *?f64,
    chips: *?f64,
) !void {
    try stdout.print("Whats your bet!?\n", .{});
    try stdout.flush();
    while (stdin.takeDelimiterExclusive('\n')) |raw| {
        //        _ = try stdin.discardShort(1);
        const input = std.fmt.parseFloat(f64, raw) catch |err| {
            switch (err) {
                std.fmt.ParseFloatError.InvalidCharacter => {
                    try stdout.print("ERR: INVALID INTEGER!\n", .{});
                    try stdout.flush();
                    continue;
                },
            }
        };
        if (input <= chips.*.?) {
            bet.* = input;
            chips.*.? -= input;
            try stdout.print("CURRENT BET: {d:.2}\n", .{input});
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
