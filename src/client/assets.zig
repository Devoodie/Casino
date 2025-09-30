const rl = @import("raylib");

const prefix = "bicycle-130";

pub fn loadCardTextures() void {
    const heart_two = try rl.loadTexture("./assets" ++ prefix ++ "heart_2.jpg");
    _ = heart_two;
}

pub const card_assets = struct {};
