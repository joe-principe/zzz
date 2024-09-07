const std = @import("std");

const zzz = @import("game");

const vaxis = @import("vaxis");

const up_keys: [4]u21 = .{ 'w', 'k', vaxis.Key.up, vaxis.Key.kp_up };
const down_keys: [4]u21 = .{ 's', 'j', vaxis.Key.down, vaxis.Key.kp_down };
const left_keys: [4]u21 = .{ 'a', 'h', vaxis.Key.left, vaxis.Key.kp_left };
const right_keys: [4]u21 = .{ 'd', 'l', vaxis.Key.right, vaxis.Key.kp_right };
const select_keys: [3]u21 = .{ vaxis.Key.enter, vaxis.Key.kp_enter, vaxis.Key.space };

/// The possible events vaxis can receive
const Event = union(enum) {
    /// An input from the keyboard
    key_press: vaxis.Key,

    /// Resizing the window
    winsize: vaxis.Winsize,
};

/// A container for the TUI state
pub const TuiApp = struct {
    const Self = @This();

    /// The memory allocator
    allocator: std.mem.Allocator,

    /// A flag for if the app should close
    should_quit: bool,

    /// The teletype terminal
    tty: vaxis.Tty,

    /// The vaxis struct (not sure what this is, lol)
    vx: vaxis.Vaxis,

    /// The event loop
    loop: vaxis.Loop(Event),

    /// Sets the default values of the TUI
    pub fn init(allocator: std.mem.Allocator) !TuiApp {
        return .{
            .allocator = allocator,
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .loop = undefined,
        };
    }

    /// Sets the default values of the TUI event loop and starts the loop
    pub fn init_loop(self: *Self) !void {
        self.loop = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try self.loop.init();
        try self.loop.start();
    }

    /// Stops the TUI event loop and deinitializes the TUI
    pub fn deinit(self: *Self) void {
        self.loop.stop();
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    /// Prints the start menu
    pub fn printStartScreen(self: *Self) !void {
        while (true) {
            const win = self.vx.window();
            win.clear();

            const txt: vaxis.Segment = .{
                .text = "Zig-Zag-Zoe",
            };
            _ = try win.printSegment(txt, .{});

            const info: vaxis.Segment = .{
                .text = "Press any key to continue",
            };
            _ = try win.printSegment(info, .{ .row_offset = 2 });

            win.hideCursor();

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) {
                        self.should_quit = true;
                        break;
                    } else {
                        break;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    /// Lets the user choose the type of a player
    pub fn choosePlayer(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) !void {
        var selected_option: usize = 0;

        const options = [_][]const u8{
            "Human",
            "Computer",
        };

        const mark: u8 = if (player == 0) 'X' else 'O';

        while (true) {
            const win = self.vx.window();
            win.clear();

            const txt: vaxis.Segment = .{
                .text = try std.fmt.allocPrint(self.allocator, "Choose player {d} ({c}): ", .{ player + 1, mark }),
            };
            defer self.allocator.free(txt.text);

            _ = try win.printSegment(txt, .{});

            win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{
                    .text = opt,
                    .style = if (i == selected_option) .{ .reverse = true } else .{},
                }};
                _ = try win.print(&seg, .{ .row_offset = i + 2 });
            }

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matchesAny(&up_keys, .{})) {
                        selected_option -|= 1;
                    } else if (key.matchesAny(&down_keys, .{})) {
                        selected_option = @min(options.len - 1, selected_option + 1);
                    } else if (key.matchesAny(&select_keys, .{})) {
                        game.players[player] = if (selected_option == 0) .Local else zzz.Player{ .Computer = undefined };
                        break;
                    } else if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) {
                        self.should_quit = true;
                        break;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    /// Lets the user choose the difficulty of a bot player
    pub fn chooseBotDifficulty(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) !void {
        var selected_option: usize = 0;
        const options = [_][]const u8{
            "Easy",
            "Medium",
            "Minimax",
            "Cache",
            "FastCache",
            "Alpha-Beta",
        };

        while (true) {
            const win = self.vx.window();
            win.clear();

            const txt: vaxis.Segment = .{
                .text = try std.fmt.allocPrint(self.allocator, "Choose bot {d} difficulty: ", .{player + 1}),
            };
            defer self.allocator.free(txt.text);
            _ = try win.printSegment(txt, .{});

            win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{ .text = opt, .style = if (i == selected_option) .{ .reverse = true } else .{} }};
                _ = try win.print(&seg, .{ .row_offset = i + 2 });
            }

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matchesAny(&up_keys, .{})) {
                        selected_option -|= 1;
                    } else if (key.matchesAny(&down_keys, .{})) {
                        selected_option = @min(options.len - 1, selected_option + 1);
                    } else if (key.matchesAny(&select_keys, .{})) {
                        game.players[player].Computer = @enumFromInt(selected_option);

                        // Have to clear here, otherwise some options will still
                        // be shown when printing the board
                        win.clear();
                        break;
                    } else if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) {
                        self.should_quit = true;
                        break;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    /// Prints out the board
    pub fn printBoard(self: *Self, game: *zzz.Game) !void {
        const b = game.board.toString();

        const win = self.vx.window();

        var player: u8 = undefined;
        var mark: u8 = undefined;
        if (game.current_player == zzz.Mark.X) {
            player = 1;
            mark = 'X';
        } else {
            player = 2;
            mark = 'O';
        }

        const trn: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "Turn {d}. Player {d}'s ({c}) turn.", .{ game.turn, player, mark }),
        };
        defer self.allocator.free(trn.text);

        const hdr: vaxis.Segment = .{
            .text = "     1     2     3  ",
        };

        const row: vaxis.Segment = .{
            .text = "        \u{2551}     \u{2551}     ",
        };

        const div: vaxis.Segment = .{ .text = "   \u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}" };

        const top: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "A    {c}  {u}  {c}  {u}  {c}  ", .{ b[0], '\u{2551}', b[1], '\u{2551}', b[2] }),
        };
        defer self.allocator.free(top.text);

        const mid: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "B    {c}  {u}  {c}  {u}  {c}  ", .{ b[3], '\u{2551}', b[4], '\u{2551}', b[5] }),
        };
        defer self.allocator.free(mid.text);

        const bot: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "C    {c}  {u}  {c}  {u}  {c}  ", .{ b[6], '\u{2551}', b[7], '\u{2551}', b[8] }),
        };
        defer self.allocator.free(bot.text);

        _ = try win.printSegment(trn, .{});
        _ = try win.printSegment(hdr, .{ .row_offset = 2 });

        _ = try win.printSegment(row, .{ .row_offset = 4 });
        _ = try win.printSegment(top, .{ .row_offset = 5 });
        _ = try win.printSegment(row, .{ .row_offset = 6 });

        _ = try win.printSegment(div, .{ .row_offset = 7 });

        _ = try win.printSegment(row, .{ .row_offset = 8 });
        _ = try win.printSegment(mid, .{ .row_offset = 9 });
        _ = try win.printSegment(row, .{ .row_offset = 10 });

        _ = try win.printSegment(div, .{ .row_offset = 11 });

        _ = try win.printSegment(row, .{ .row_offset = 12 });
        _ = try win.printSegment(bot, .{ .row_offset = 13 });
        _ = try win.printSegment(row, .{ .row_offset = 14 });

        try self.vx.render(self.tty.anyWriter());

        // Get an event if there is one
        // tryEvent() instead of nextEvent() because any blocking calls cause
        // getLocalMove() to "lag" whenever a button is pressed due to a
        // blocking call here
        const event = self.loop.tryEvent() orelse return;
        switch (event) {
            .key_press => |key| {
                if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) self.should_quit = true;
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
        }
    }

    /// Gets a move from a local player
    pub fn getLocalMove(self: *Self, game: *zzz.Game) !u8 {
        var pos: u8 = undefined;

        // Static struct so that the cursor is kept in the same position in
        // between turns. Otherwise, it'd reset to the center everytime, which
        // is really annoying when playing

        // Cursor coordinates (0, 0) is top left, (2, 2) is bottom right
        const cursor_pos = struct {
            var x: u8 = 1;
            var y: u8 = 1;
        };

        while (true) {
            const win = self.vx.window();
            win.clear();

            try self.printBoard(game);

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matchesAny(&up_keys, .{})) {
                        cursor_pos.y = if (cursor_pos.y == 0) 2 else cursor_pos.y -| 1;
                    } else if (key.matchesAny(&down_keys, .{})) {
                        cursor_pos.y = if (cursor_pos.y == 2) 0 else cursor_pos.y + 1;
                    } else if (key.matchesAny(&left_keys, .{})) {
                        cursor_pos.x = if (cursor_pos.x == 0) 2 else cursor_pos.x -| 1;
                    } else if (key.matchesAny(&right_keys, .{})) {
                        cursor_pos.x = if (cursor_pos.x == 2) 0 else cursor_pos.x + 1;
                    } else if (key.matchesAny(&select_keys, .{})) {
                        pos = cursor_pos.x + 3 * cursor_pos.y;
                        if (!game.board.isPositionOccupied(pos)) break;
                    } else if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) {
                        self.should_quit = true;
                        break;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }

            const initial_x = 5;
            const initial_y = 5;

            const stride_x = 6;
            const stride_y = 4;

            const cursor_screen_x = cursor_pos.x * stride_x + initial_x;
            const cursor_screen_y = cursor_pos.y * stride_y + initial_y;
            win.showCursor(cursor_screen_x, cursor_screen_y);
        }

        return pos;
    }

    /// Prints the result screen
    pub fn printEndScreen(
        self: *Self,
        game: *zzz.Game,
        result: zzz.WinState,
    ) !void {
        var winner: u8 = undefined;
        var winner_mark: u8 = undefined;

        if (result == zzz.WinState.X) {
            winner = 1;
            winner_mark = 'X';
        } else if (result == zzz.WinState.O) {
            winner = 2;
            winner_mark = 'O';
        }

        const game_won: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "Player {d} ({c}) wins!", .{ winner, winner_mark }),
        };
        defer self.allocator.free(game_won.text);

        const tie: vaxis.Segment = .{
            .text = "The game is a tie!",
        };

        const end: vaxis.Segment = .{ .text = "Press escape to exit." };

        while (true) {
            const win = self.vx.window();
            win.clear();

            if (result == zzz.WinState.Tie) {
                _ = try win.printSegment(tie, .{ .row_offset = 16 });
            } else {
                _ = try win.printSegment(game_won, .{ .row_offset = 16 });
            }

            _ = try win.printSegment(end, .{ .row_offset = 18 });

            win.hideCursor();
            try self.printBoard(game);

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) break;
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }
};
