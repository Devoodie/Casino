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
        std.Thread.sleep(std.time.ns_per_s * 5);
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
        for (state.ids, state.chips, state.hand_value, state.bets, state.hands) |id, chips, value, bets, hand| {
            if (id == null or id == 0) {
                try stream_writer.print("null,null,null,null,null\n", .{});
                continue;
            }
            try stream_writer.print("{any},{any},{any},{any},{any}\n", .{ id.?, chips.?, value.?, bets.?, hand.? });
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
    hand_index: []?u8,
    action: Status,
};

pub const Status = enum {
    DEALING,
    HIT,
    STAND,
    DOUBLE,
    SPLIT,
    RESULT,
    ACTION,
};
