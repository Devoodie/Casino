const std = @import("std");

//nobody be using this shit

pub const cards = enum(u8) {
    SPADE_TWO = 0,
    SPADE_THREE,
    SPADE_FOUR,
    SPADE_FIVE,
    SPADE_SIX,
    SPADE_SEVEN,
    SPADE_EIGHT,
    SPADE_NINE,
    SPADE_TEN,
    SPADE_JACK,
    SPADE_QUEEN,
    SPADE_KING,
    SPADE_ACE,
    CLUB_TWO,
    CLUB_THREE,
    CLUB_FOUR,
    CLUB_FIVE,
    CLUB_SIX,
    CLUB_SEVEN,
    CLUB_EIGHT,
    CLUB_NINE,
    CLUB_TEN,
    CLUB_JACK,
    CLUB_QUEEN,
    CLUB_KING,
    CLUB_ACE,
    HEART_TWO,
    HEART_THREE,
    HEART_FOUR,
    HEART_FIVE,
    HEART_SIX,
    HEART_SEVEN,
    HEART_EIGHT,
    HEART_NINE,
    HEART_TEN,
    HEART_JACK,
    HEART_QUEEN,
    HEART_KING,
    HEART_ACE,
    DIAMOND_TWO,
    DIAMOND_THREE,
    DIAMOND_FOUR,
    DIAMOND_FIVE,
    DIAMOND_SIX,
    DIAMOND_SEVEN,
    DIAMOND_EIGHT,
    DIAMOND_NINE,
    DIAMOND_TEN,
    DIAMOND_JACK,
    DIAMOND_QUEEN,
    DIAMOND_KING,
    DIAMOND_ACE,
};

pub fn initialize_deck(allocator: std.mem.Allocator, deck: *std.ArrayList(cards), deck_amount: u8) !void {
    var card: cards = undefined;
    for (0..52) |card_number| {
        for (0..deck_amount) |_| {
            card = @enumFromInt(card_number);
            try deck.append(allocator, card);
        }
    }
    try randomize_deck(deck);
}

pub fn randomize_deck(deck: *std.ArrayList(cards)) !void {
    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rng = random.random();

    std.Random.shuffle(rng, cards, deck.items);
}
