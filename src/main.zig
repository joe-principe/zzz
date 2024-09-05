const std = @import("std");
const assert = std.debug.assert;

const ai = @import("ai");
const tui = @import("tui");
const zzz = @import("game");

pub fn main() !void {
    const seed: u64 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
    ai.rnd = std.rand.DefaultPrng.init(seed);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak", .{});
        }
    }
    const allocator = gpa.allocator();

    var app = try tui.TuiApp.init(allocator);
    try app.init_loop();
    defer app.deinit();

    var game = zzz.Game.init();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        try app.choosePlayer(&game, i);

        if (game.players[i] == zzz.PlayerType.Computer) {
            try app.chooseBotDifficulty(&game, i);

            if (game.players[i].Computer == ai.BotDifficulty.Cache) {
                ai.cache[i] = std.AutoHashMap(zzz.Board, zzz.WinState).init(allocator);
            } else if (game.players[i].Computer == ai.BotDifficulty.FastCache) {
                ai.fast_cache[i] = std.AutoHashMap(zzz.Board, zzz.WinState).init(allocator);
            }
        }
    }
    defer ai.cache[0].deinit();
    defer ai.cache[1].deinit();
    defer ai.fast_cache[0].deinit();
    defer ai.fast_cache[1].deinit();

    var game_status = zzz.WinState.None;
    while (game_status == zzz.WinState.None) {
        try app.printBoard(&game);

        var pos: u8 = undefined;
        switch (game.players[@as(usize, @intFromEnum(game.current_player))]) {
            .Local => {
                if (app.getLocalMove(&game)) |val| {
                    pos = val;
                } else |err| {
                    std.log.err("Error: {}\n", .{err});
                    return;
                }
            },
            .Computer => |difficulty| {
                switch (difficulty) {
                    .Easy => pos = ai.getEasyMove(&game),
                    .Medium => pos = ai.getMediumMove(&game),
                    .Minimax => pos = ai.getMinimaxMove(&game),
                    .Cache => {
                        if (ai.getCacheMove(&game)) |val| {
                            pos = val;
                        } else |err| {
                            std.log.err("Error: {}\n", .{err});
                            return;
                        }
                    },
                    .FastCache => {
                        if (ai.getFastCacheMove(&game)) |val| {
                            pos = val;
                        } else |err| {
                            std.log.err("Error: {}\n", .{err});
                            return;
                        }
                    },
                    .ABPruning => pos = ai.getABPruningMove(&game),
                }
            },
        }
        game.board.placeMark(game.current_player, pos);

        // Waits a second if both players are bots
        // This is so moves are visible. Otherwise, game finishes instantly
        if (game.players[0] == zzz.PlayerType.Computer and game.players[1] == zzz.PlayerType.Computer) {
            std.time.sleep(1 * std.time.ns_per_s);
        }

        game.nextTurn();
        game_status = game.board.getWinState(game.turn);
    }

    try app.printEndScreen(&game, game_status);
}
