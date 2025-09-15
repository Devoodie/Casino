const std = @import("std");
const deck_utils = @import("decks.zig");

pub fn accept_connections(address: *std.net.Address, connections: []?std.net.Server.Connection, state: *gamestate) !void {
    var server = try address.listen(.{.kernel_backlog = 7, .reuse_address = true});
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


pub fn handle_requests(connections: []?std.net.Server.Connection) !void {
}
pub const gamestate = struct {
    ids: []?u16,
    chips: []?f64,
    hand_value: []?u8,
    bets: []?f64,
    hands: []?std.ArrayList(deck_utils.cards),
};

//pub fn 0
