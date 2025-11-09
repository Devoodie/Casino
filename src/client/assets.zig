const std = @import("std");
const rl = @import("raylib");
const deck_utils = @import("deck_utils");

const prefix = "bicycle-130";
pub var card_textures: [53]rl.Texture2D = undefined;

pub fn loadCardTextures() !void {
    var allocator_config = std.heap.DebugAllocator(.{}).init;
    const allocator = allocator_config.allocator();

    const heart_two = try rl.loadTexture("./assets/" ++ prefix ++ "/heart_2.jpg");
    card_textures[0] = heart_two;

    var index_enum: deck_utils.cards = undefined;
    var buffer: [1024]u8 = undefined;
    var card_name: []u8 = undefined;
    var vector = try std.ArrayList(u8).initCapacity(allocator, 1024);

    for (&card_textures, 0..) |*texture, index| {
        if (index == 52) continue;
        index_enum = @enumFromInt(index);
        card_name = std.ascii.lowerString(&buffer, @tagName(index_enum));

        std.debug.print("CARD NAME: {s}\n", .{card_name});
        vector.appendSliceAssumeCapacity("./assets/");
        vector.appendSliceAssumeCapacity(prefix);
        vector.appendAssumeCapacity('/');
        vector.appendSliceAssumeCapacity(card_name);
        vector.appendSliceAssumeCapacity(".jpg");
        vector.appendAssumeCapacity(0);
        texture.* = try rl.loadTexture(vector.items[0 .. vector.items.len - 1 :0]);
        vector.clearRetainingCapacity();
    }
    vector.deinit(allocator);
    _ = allocator_config.deinit();
}

pub const card_assets = struct {};
