const std = @import("std");

const zzz = @import("game");

const vaxis = @import("vaxis");

const up_keys: [4]u21 = .{ 'w', 'k', vaxis.Key.up, vaxis.Key.kp_up };
const down_keys: [4]u21 = .{ 's', 'j', vaxis.Key.down, vaxis.Key.kp_down };
const left_keys: [4]u21 = .{ 'a', 'h', vaxis.Key.left, vaxis.Key.kp_left };
const right_keys: [4]u21 = .{ 'd', 'l', vaxis.Key.right, vaxis.Key.kp_right };
const select_keys: [3]u21 = .{ vaxis.Key.enter, vaxis.Key.kp_enter, vaxis.Key.space };

const x_color: vaxis.Style = .{ .fg = vaxis.Cell.Color.rgbFromUint(0x008DF1) };
const o_color: vaxis.Style = .{ .fg = vaxis.Cell.Color.rgbFromUint(0xFDF900) };
const white: vaxis.Style = .{ .fg = vaxis.Cell.Color.rgbFromUint(0xFFFFFF) };

const title_wide =
    \\ ______     __     ______     ______     ______     ______     ______     ______     ______    
    \\/\__   \   /\ \   /\  ___\   /\__   \   /\  __ \   /\  ___\   /\__   \   /\  __ \   /\  ___\   
    \\\/_/  /__  \ \ \  \ \ \__ \  \/_/  /__  \ \  __ \  \ \ \__ \  \/_/  /__  \ \ \/\ \  \ \  __\   
    \\  /\_____\  \ \_\  \ \_____\   /\_____\  \ \_\ \_\  \ \_____\   /\_____\  \ \_____\  \ \_____\ 
    \\  \/_____/   \/_/   \/_____/   \/_____/   \/_/\/_/   \/_____/   \/_____/   \/_____/   \/_____/ 
;
const tw_len = 95;

const title_thin =
    \\  _____         ____             ____         
    \\ |_  (_)__ _ __|_  /__ _ __ _ __|_  /___  ___ 
    \\  / /| / _` |___/ // _` / _` |___/ // _ \/ -_)
    \\ /___|_\__, |  /___\__,_\__, |  /___\___/\___|
    \\       |___/            |___/                 
;
const tt_len = 46;

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
    pub fn setup(self: *Self) !void {
        self.loop = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };

        try self.loop.init();
        try self.loop.start();

        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);
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

            const title_offset: usize = if (win.width >= tw_len) tw_len else tt_len;
            const title_win = win.child(.{
                .x_off = @divFloor(win.width -| title_offset, 2),
                .y_off = @divFloor(win.height -| 5, 2),
            });

            const txt: vaxis.Segment = .{
                .text = if (win.width >= 95) title_wide else title_thin,
            };
            _ = try title_win.printSegment(txt, .{});

            const info: vaxis.Segment = .{
                .text = "Press any key to continue",
            };
            const info_off_x: usize = @divFloor(win.width -| info.text.len, 2);
            const info_off_y: usize = @divFloor(win.height -| 5, 2) + 9;
            _ = try win.printSegment(info, .{ .row_offset = info_off_y, .col_offset = info_off_x });

            win.hideCursor();

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matches(vaxis.Key.escape, .{}) or key.matches('c', .{ .ctrl = true })) {
                        self.should_quit = true;
                        break;
                    }
                    // Where's the "any" key? (goes to next menu on any keypress)
                    else break;
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

            const child_win = win.child(.{
                .x_off = @divFloor(win.width -| txt.text.len, 2),
                .y_off = @divFloor(win.height -| 4, 2),
                .width = .{ .limit = txt.text.len },
            });

            _ = try child_win.printSegment(txt, .{});

            child_win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{
                    .text = opt,
                    .style = if (i == selected_option) .{ .reverse = true } else .{},
                }};
                _ = try child_win.print(&seg, .{ .row_offset = i + 2 });
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

            const child_win = win.child(.{
                .x_off = @divFloor(win.width -| txt.text.len, 2),
                .y_off = @divFloor(win.height -| 8, 2),
                .width = .{ .limit = txt.text.len },
            });
            _ = try child_win.printSegment(txt, .{});

            child_win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{ .text = opt, .style = if (i == selected_option) .{ .reverse = true } else .{} }};
                _ = try child_win.print(&seg, .{ .row_offset = i + 2 });
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
        const child_win = win.child(.{
            .x_off = @divFloor(win.width -| 29, 2),
            .y_off = @divFloor(win.height -| 15, 2),
        });

        const player: u8 = if (game.current_player == zzz.Mark.X) 1 else 2;
        const mark = if (game.current_player == zzz.Mark.X) "X" else "O";
        const color = if (game.current_player == zzz.Mark.X) x_color else o_color;

        const trn: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "Turn {d}. ", .{game.turn}),
        };
        defer self.allocator.free(trn.text);

        const plr_offset = trn.text.len;
        const plr: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "Player {d} ", .{player}),
            .style = color,
        };
        defer self.allocator.free(plr.text);

        const lpr_offset = plr.text.len + plr_offset;
        const lpr: vaxis.Segment = .{
            .text = "(",
        };

        const chr_offset = lpr.text.len + lpr_offset;
        const chr: vaxis.Segment = .{
            .text = mark,
            .style = color,
        };

        const rpr_offset = chr.text.len + chr_offset;
        const rpr: vaxis.Segment = .{
            .text = ")'s turn.",
        };

        const hdr: vaxis.Segment = .{
            .text = "     1     2     3  ",
        };

        const row: vaxis.Segment = .{
            .text = "        \u{2551}     \u{2551}     ",
        };

        const div: vaxis.Segment = .{ .text = "   \u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}" };

        const top: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "A       {u}     {u}     ", .{ '\u{2551}', '\u{2551}' }),
        };
        defer self.allocator.free(top.text);

        const mid: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "B       {u}     {u}     ", .{ '\u{2551}', '\u{2551}' }),
        };
        defer self.allocator.free(mid.text);

        const bot: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "C       {u}     {u}     ", .{ '\u{2551}', '\u{2551}' }),
        };
        defer self.allocator.free(bot.text);

        _ = try child_win.printSegment(trn, .{});
        _ = try child_win.printSegment(plr, .{ .col_offset = plr_offset });
        _ = try child_win.printSegment(lpr, .{ .col_offset = lpr_offset });
        _ = try child_win.printSegment(chr, .{ .col_offset = chr_offset });
        _ = try child_win.printSegment(rpr, .{ .col_offset = rpr_offset });

        _ = try child_win.printSegment(hdr, .{ .row_offset = 2, .col_offset = 4 });

        _ = try child_win.printSegment(row, .{ .row_offset = 4, .col_offset = 4 });
        _ = try child_win.printSegment(top, .{ .row_offset = 5, .col_offset = 4 });
        _ = try child_win.printSegment(row, .{ .row_offset = 6, .col_offset = 4 });

        _ = try child_win.printSegment(div, .{ .row_offset = 7, .col_offset = 4 });

        _ = try child_win.printSegment(row, .{ .row_offset = 8, .col_offset = 4 });
        _ = try child_win.printSegment(mid, .{ .row_offset = 9, .col_offset = 4 });
        _ = try child_win.printSegment(row, .{ .row_offset = 10, .col_offset = 4 });

        _ = try child_win.printSegment(div, .{ .row_offset = 11, .col_offset = 4 });

        _ = try child_win.printSegment(row, .{ .row_offset = 12, .col_offset = 4 });
        _ = try child_win.printSegment(bot, .{ .row_offset = 13, .col_offset = 4 });
        _ = try child_win.printSegment(row, .{ .row_offset = 14, .col_offset = 4 });

        // Column positions
        const col_left = 9;
        const col_center = 15;
        const col_right = 21;

        // Row positions
        const row_top = 5;
        const row_middle = 9;
        const row_bottom = 13;

        // Draw the marks
        for (0..3) |j| {
            for (0..3) |i| {
                const index = i + 3 * j;

                const x: u16 = if (i == 0) col_left else if (i == 1) col_center else col_right;
                const y: u16 = if (j == 0) row_top else if (j == 1) row_middle else row_bottom;

                // Raylib only accepts c-strings, not chars, hence this junk below
                const seg: vaxis.Segment = .{
                    .text = if (b[index] == 'X') "X" else if (b[index] == 'O') "O" else " ",
                    .style = if (b[index] == 'X') x_color else if (b[index] == 'O') o_color else white,
                };

                _ = try child_win.printSegment(seg, .{ .row_offset = y, .col_offset = x });
            }
        }

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

            const child_win = win.child(.{
                .x_off = @divFloor(win.width -| 29, 2) + 4,
                .y_off = @divFloor(win.height -| 15, 2),
            });

            const initial_x = 5;
            const initial_y = 5;

            const stride_x = 6;
            const stride_y = 4;

            const cursor_screen_x = cursor_pos.x * stride_x + initial_x;
            const cursor_screen_y = cursor_pos.y * stride_y + initial_y;
            child_win.showCursor(cursor_screen_x, cursor_screen_y);

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
        }

        return pos;
    }

    /// Prints the result screen
    pub fn printEndScreen(
        self: *Self,
        game: *zzz.Game,
        result: zzz.WinState,
    ) !void {
        const winner: u8 = if (result == zzz.WinState.X) 1 else 2;
        const winner_mark = if (result == zzz.WinState.X) "X" else "O";
        const color = if (result == zzz.WinState.X) x_color else o_color;

        const plr: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "Player {d} ", .{winner}),
            .style = color,
        };
        defer self.allocator.free(plr.text);

        const lpr_offset = plr.text.len;
        const lpr: vaxis.Segment = .{
            .text = "(",
        };

        const chr_offset = lpr.text.len + lpr_offset;
        const chr: vaxis.Segment = .{
            .text = winner_mark,
            .style = color,
        };

        const rpr_offset = chr.text.len + chr_offset;
        const rpr: vaxis.Segment = .{
            .text = ") wins!",
        };

        const tie: vaxis.Segment = .{
            .text = "The game is a tie!",
        };

        const end: vaxis.Segment = .{ .text = "Press escape to exit." };

        while (true) {
            const win = self.vx.window();
            win.clear();

            const child_win = win.child(.{
                .x_off = @divFloor(win.width -| 29, 2) + 4,
                .y_off = @divFloor(win.height -| 15, 2),
            });

            if (result == zzz.WinState.Tie) {
                _ = try child_win.printSegment(tie, .{ .row_offset = 16 });
            } else {
                _ = try child_win.printSegment(plr, .{ .row_offset = 16 });
                _ = try child_win.printSegment(lpr, .{ .row_offset = 16, .col_offset = lpr_offset });
                _ = try child_win.printSegment(chr, .{ .row_offset = 16, .col_offset = chr_offset });
                _ = try child_win.printSegment(rpr, .{ .row_offset = 16, .col_offset = rpr_offset });
            }

            _ = try child_win.printSegment(end, .{ .row_offset = 18 });

            child_win.hideCursor();
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
