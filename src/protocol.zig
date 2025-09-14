const std = @import("std");
const deck_utils = @import("decks.zig");

pub fn accept_connections(server: *std.net.Address, connections: []?std.net.Server.Connection, state: *gamestate) !void {
    _ = server;
    _ = connections;
    _ = state;
}

pub const gamestate = struct {
    ids: []?u16,
    chips: []?f64,
    hand_value: []?u8,
    bets: []?f64,
    hands: []?std.ArrayList(deck_utils.cards),
};

//pub fn 0
