const std = @import("std");
const deck_utils = @import("decks.zig");

pub fn acceptConnections(address: *std.net.Address, connections: []?std.net.Server.Connection, state: *Gamestate) !void {
    var server = try address.listen(.{ .kernel_backlog = 7, .reuse_address = true });
    defer server.deinit();

    //    _ = state;
    std.debug.print("THREAD 2 GAMESTATE: ID{d}", .{state.ids[1].?});
    while (true) {
        for (connections) |*connection| {
            if (connection.* != null) continue;
            connection.* = try server.accept();
        }
        std.Thread.sleep(std.time.ns_per_s * 5);
    }
}

pub fn sendGameState(connections: []?std.net.Server.Connection) !void {
    var stream_writer: *std.Io.Writer = undefined;
    var out_buffer: [4096]u8 = undefined;

    while (true) {
        for (connections) |*connection| {
            if (connection.* == null) continue;
            stream_writer = &connection.*.?.stream.writer(&out_buffer).interface;
            try stream_writer.print("THIS IS A PRINTING TEST", .{});
            try stream_writer.flush();
        }
        std.Thread.sleep(std.time.ns_per_s * 5);
    }
}
pub const Gamestate = struct {
    ids: []?u16,
    chips: []?f64,
    hand_value: []?u8,
    bets: []?f64,
    hands: []?std.ArrayList(deck_utils.cards),
};

//pub fn 0
