const std = @import("std");
const assert = std.debug.assert;

const ai = @import("ai");
const gui = @import("gui");
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

    const gui_mode: bool = @import("build_options").gui;

    var tui_app: tui.TuiApp = undefined;
    var gui_app: gui.GuiApp = undefined;

    if (gui_mode) {
        gui_app = gui.GuiApp.init(allocator);
    } else {
        tui_app = try tui.TuiApp.init(allocator);
        try tui_app.init_loop();
    }
    defer if (gui_mode) gui.GuiApp.deinit() else tui_app.deinit();

    var game = zzz.Game.init();

    if (gui_mode) gui_app.printStartScreen() else try tui_app.printStartScreen();
    if (gui_mode) {
        if (gui_app.should_quit) return;
    } else {
        if (tui_app.should_quit) return;
    }

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        if (gui_mode) gui_app.choosePlayer(&game, i) else try tui_app.choosePlayer(&game, i);
        if (gui_mode) {
            if (gui_app.should_quit) return;
        } else {
            if (tui_app.should_quit) return;
        }

        if (game.players[i] == zzz.PlayerType.Computer) {
            if (gui_mode) gui_app.chooseBotDifficulty(&game, i) else try tui_app.chooseBotDifficulty(&game, i);
            if (gui_mode) {
                if (gui_app.should_quit) return;
            } else {
                if (tui_app.should_quit) return;
            }

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
        if (gui_mode) try gui_app.printBoard(&game) else try tui_app.printBoard(&game);
        if (gui_mode) {
            if (gui_app.should_quit) return;
        } else {
            if (tui_app.should_quit) return;
        }

        const player_num = @intFromEnum(game.current_player);

        var pos: u8 = undefined;
        switch (game.players[player_num]) {
            .Local => {
                if (gui_mode) {
                    if (gui_app.getLocalMove(&game)) |val| {
                        if (gui_app.should_quit) return;
                        pos = val;
                    } else |err| {
                        std.log.err("Error: {}\n", .{err});
                        return;
                    }
                } else {
                    if (tui_app.getLocalMove(&game)) |val| {
                        if (tui_app.should_quit) return;
                        pos = val;
                    } else |err| {
                        std.log.err("Error: {}\n", .{err});
                        return;
                    }
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

    if (gui_mode) {
        try gui_app.printEndScreen(&game, game_status);
    } else {
        try tui_app.printEndScreen(&game, game_status);
    }
}
