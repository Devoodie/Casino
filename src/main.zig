const std = @import("std");
const games = @import("games.zig");

pub fn main() !void {
    var allocator_config = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = allocator_config.allocator();

    try games.blackjack(gpa);

    _ = allocator_config.deinit();
}
