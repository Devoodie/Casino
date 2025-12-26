const std = @import("std");
const deck_utils = @import("deck_utils");

pub fn acceptConnections(address: *std.net.Address, connections: []?std.net.Server.Connection, state: *Gamestate) !void {
    var server = try address.listen(.{ .kernel_backlog = 7, .reuse_address = true });
    defer server.deinit();

    _ = state;
    while (true) {
        for (connections) |*connection| {
            if (connection.* != null) continue;
            connection.* = try server.accept();
        }
    }
}

pub fn sendGameState(connections: []?std.net.Server.Connection, state: Gamestate) !void {
    var stream_writer: *std.Io.Writer = undefined;
    var out_buffer: [4096]u8 = undefined;

    //    while (true) {
    for (connections) |*connection| {
        if (connection.* == null) continue;
        var stream = connection.*.?.stream.writer(&out_buffer);
        stream_writer = &stream.interface;

        try stream_writer.print("STATE\n", .{});
        for (state.ids, state.chips, state.hand_value, state.hands, state.bets) |id, chips, value, hands, bets| {
            //id
            //chips
            //bets
            //action
            //hand_index
            //hands
            //hand value
            //player_turn
            if (id == null) {
                try stream_writer.print("null,null,null,null,null\n", .{});
                continue;
            }
            if (id.? != 0) {
                try stream_writer.print("{d},{d:.2},{d:.2},{any},{d},", .{
                    id.?,
                    chips.?,
                    bets.?,
                    //MAKE THIS INTFROM ENUM
                    state.action,
                    state.hand_index,
                });

                for (hands.?.items) |hand| {
                    for (hand.items) |card| {
                        try stream_writer.print("{any}[", .{card});
                    }
                    try stream_writer.print(";", .{});
                }
                try stream_writer.print(",", .{});

                for (value.?.items) |hand_value| {
                    if (hand_value == null) {
                        try stream_writer.print("null;", .{});
                    } else {
                        try stream_writer.print("{d};", .{hand_value.?});
                    }
                }

                try stream_writer.print(",", .{});

                try stream_writer.print("{d}\n", .{state.player_turn});
            } else {
                try stream_writer.print("{d},null,null,{any},{d},", .{
                    id.?,
                    //MAKE THIS INTFROM ENUM
                    state.action,
                    state.hand_index,
                });

                //if action != result then show card back else show dealer cards
                if (state.action != Status.RESULT and state.action != Status.DEALER_HIT) {
                    try stream_writer.print("{any}]{any}];,", .{
                        //MAKE THESE INT FROM ENUM
                        state.hands[0].?.items[0].items[1],
                        deck_utils.cards.CARD_BACK,
                    });
                } else {
                    for (hands.?.items) |hand| {
                        for (hand.items) |card| {
                            try stream_writer.print("{any}[", .{card});
                        }
                        try stream_writer.print(";", .{});
                    }
                    try stream_writer.print(",", .{});
                }
                try stream_writer.print("{d},", .{value.?.items[0].?});
                try stream_writer.print("{any}\n", .{state.player_turn});
            }
        }

        stream_writer.flush() catch {
            switch (stream.err.?) {
                std.net.Stream.Writer.Error.BrokenPipe => {
                    std.debug.print("Client Disconnected: Broken Pipe\n", .{});
                    connection.* = null;
                },
                else => {
                    std.debug.print("Unhandled Error: {any}", .{stream.err.?});
                },
            }
        };
    }
}
pub const Gamestate = struct {
    ids: []?u16,
    chips: []?f32,
    hand_value: []?std.ArrayList(?u8),
    bets: []?f32,
    hands: []?std.ArrayList(std.ArrayList(deck_utils.cards)),
    player_turn: u8,
    hand_index: u8,
    action: Status,
};

pub const Status = enum {
    DEALING,
    HIT,
    DEALER_HIT,
    STAND,
    DOUBLE,
    SPLIT,
    RESULT,
    ACTION,
    DONE,
};
