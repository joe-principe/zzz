const std = @import("std");
const assert = std.debug.assert;
const vaxis = @import("vaxis");

const up_keys: [4]u21 = .{ 'w', 'k', vaxis.Key.up, vaxis.Key.kp_up };
const down_keys: [4]u21 = .{ 's', 'j', vaxis.Key.down, vaxis.Key.kp_down };
const left_keys: [4]u21 = .{ 'a', 'h', vaxis.Key.left, vaxis.Key.kp_left };
const right_keys: [4]u21 = .{ 'd', 'l', vaxis.Key.right, vaxis.Key.kp_right };
const select_keys: [3]u21 = .{ vaxis.Key.enter, vaxis.Key.kp_enter, vaxis.Key.space };

const Mark = enum(u1) {
    X,
    O,

    comptime {
        for (0..std.enums.values(Mark).len) |i| {
            const res: Mark = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

const Player = union(PlayerType) {
    Local,
    Computer: BotDifficulty,
};

const PlayerType = enum(u1) {
    Local,
    Computer,

    comptime {
        for (0..std.enums.values(PlayerType).len) |i| {
            const res: PlayerType = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

const BotDifficulty = enum(u3) {
    Easy,
    Medium,
    Minimax,
    Cache,
    FastCache,
    ABPruning,
    PreCache,

    comptime {
        for (0..std.enums.values(PlayerType).len) |i| {
            const res: BotDifficulty = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

const WinState = enum(u2) {
    None,
    X,
    O,
    Tie,

    comptime {
        for (0..std.enums.values(WinState).len) |i| {
            const res: WinState = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

const Board = struct {
    const Self = @This();

    x: u9,
    o: u9,

    // Note: << operator is borked rn (zig 0.13.0)

    fn isPositionOccupied(self: *Self, pos: u8) bool {
        const x_empty: bool = (self.x & std.math.shl(u9, 1, (9 - (pos + 1)))) == 0;
        const o_empty: bool = (self.o & std.math.shl(u9, 1, (9 - (pos + 1)))) == 0;

        return if (x_empty and o_empty) false else true;
    }

    fn placeMark(self: *Self, mark: Mark, pos: u8) void {
        switch (mark) {
            Mark.X => {
                self.x |= std.math.shl(u9, 1, (9 - (pos + 1)));
            },
            Mark.O => {
                self.o |= std.math.shl(u9, 1, (9 - (pos + 1)));
            },
        }
    }

    fn toSlice(self: *Self) [9]u8 {
        var b: [9]u8 = .{ ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' };

        for (0..9) |i| {
            const mask = std.math.shl(u9, 1, (9 - (i + 1)));

            if ((self.x & mask) != 0) {
                b[i] = 'X';
                continue;
            } else if ((self.o & mask) != 0) {
                b[i] = 'O';
                continue;
            }
        }

        return b;
    }

    fn getLegalMoves(self: *Self) []u8 {
        var legal: [9]u8 = undefined;
        var i: u8 = 0;
        var j: u8 = 0;

        while (i < 9) : (i += 1) {
            if (!self.isPositionOccupied(i)) {
                legal[j] = i;
                j += 1;
            }
        }

        return legal[0..j];
    }
};

const Game = struct {
    const Self = @This();

    board: Board,
    turn: u8,
    current_player: Mark,
    players: [2]Player,

    fn init() Game {
        return .{
            .board = .{ .x = 0, .o = 0 },
            .turn = 1,
            .current_player = Mark.X,
            .players = undefined,
        };
    }

    fn checkForWin(self: *Self) WinState {
        const winning_boards = [_]u9{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };

        for (winning_boards) |board| {
            if (self.board.x & board == board) {
                return WinState.X;
            } else if (self.board.o & board == board) {
                return WinState.O;
            }
        }

        if (self.turn == 10) {
            return WinState.Tie;
        } else {
            return WinState.None;
        }
    }

    fn nextTurn(self: *Self) void {
        self.turn += 1;
        self.current_player = if (self.current_player == Mark.X) Mark.O else Mark.X;
    }
};

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const TuiApp = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    loop: vaxis.Loop(Event),

    fn init(allocator: std.mem.Allocator) !TuiApp {
        return .{
            .allocator = allocator,
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .loop = undefined,
        };
    }

    fn init_loop(self: *Self) !void {
        self.loop = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try self.loop.init();
        try self.loop.start();
    }

    fn deinit(self: *Self) void {
        self.loop.stop();
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    fn setPlayer(self: *Self, game: *Game, player: u1) !void {
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
                .text = try std.fmt.allocPrint(self.allocator, "Choose player {d} ({c}): ", .{ @as(u2, player) + 1, mark }),
            };
            defer self.allocator.free(txt.text);

            _ = try win.printSegment(txt, .{});

            win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{
                    .text = opt,
                    .style = if (i == selected_option) .{ .reverse = true } else .{},
                }};
                _ = try win.print(&seg, .{ .row_offset = i + 1 });
            }

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    // Go up an option
                    if (key.matchesAny(&up_keys, .{})) {
                        selected_option -|= 1;
                    }
                    // Go down an option
                    else if (key.matchesAny(&down_keys, .{})) {
                        selected_option = @min(options.len - 1, selected_option + 1);
                    }
                    // Select an option
                    else if (key.matchesAny(&select_keys, .{})) {
                        game.players[player] = if (selected_option == 0) .Local else Player{ .Computer = undefined };
                        break;
                    }
                    // N/A
                    else {}
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    fn setBotDifficulty(self: *Self, game: *Game, player: u1) !void {
        var selected_option: usize = 0;
        const options = [_][]const u8{
            "Easy",
            "Medium",
            "Minimax",
            "Cache",
            "FastCache",
            "Alpha-Beta",
            "PreCache",
        };

        while (true) {
            const win = self.vx.window();
            win.clear();

            const txt: vaxis.Segment = .{
                .text = "Pick a difficulty: ",
            };

            _ = try win.printSegment(txt, .{});

            win.hideCursor();
            for (options, 0..) |opt, i| {
                var seg = [_]vaxis.Segment{.{ .text = opt, .style = if (i == selected_option) .{ .reverse = true } else .{} }};
                _ = try win.print(&seg, .{ .row_offset = i + 1 });
            }

            try self.vx.render(self.tty.anyWriter());

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    // Go up an option
                    if (key.matchesAny(&up_keys, .{})) {
                        selected_option -|= 1;
                    }
                    // Go down an option
                    else if (key.matchesAny(&down_keys, .{})) {
                        selected_option = @min(options.len - 1, selected_option + 1);
                    }
                    // Select an option
                    else if (key.matchesAny(&select_keys, .{})) {
                        game.players[player].Computer = @enumFromInt(selected_option);
                    }
                    // N/A
                    else {}
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    fn printBoard(self: *Self, game: *Game) !void {
        const b = game.board.toSlice();

        const win = self.vx.window();
        win.clear();

        const hdr: vaxis.Segment = .{
            .text = "    1     2     3  ",
        };

        const row: vaxis.Segment = .{
            .text = "       \u{2551}     \u{2551}     ",
        };

        const div: vaxis.Segment = .{ .text = "  \u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{256C}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}" };

        const top: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "A   {c}  {u}  {c}  {u}  {c}  ", .{ b[0], '\u{2551}', b[1], '\u{2551}', b[2] }),
        };
        defer self.allocator.free(top.text);

        const mid: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "B   {c}  {u}  {c}  {u}  {c}  ", .{ b[3], '\u{2551}', b[4], '\u{2551}', b[5] }),
        };
        defer self.allocator.free(mid.text);

        const bot: vaxis.Segment = .{
            .text = try std.fmt.allocPrint(self.allocator, "C   {c}  {u}  {c}  {u}  {c}  ", .{ b[6], '\u{2551}', b[7], '\u{2551}', b[8] }),
        };
        defer self.allocator.free(bot.text);

        _ = try win.printSegment(hdr, .{});

        _ = try win.printSegment(row, .{ .row_offset = 2 });
        _ = try win.printSegment(top, .{ .row_offset = 3 });
        _ = try win.printSegment(row, .{ .row_offset = 4 });

        _ = try win.printSegment(div, .{ .row_offset = 5 });

        _ = try win.printSegment(row, .{ .row_offset = 6 });
        _ = try win.printSegment(mid, .{ .row_offset = 7 });
        _ = try win.printSegment(row, .{ .row_offset = 8 });

        _ = try win.printSegment(div, .{ .row_offset = 9 });

        _ = try win.printSegment(row, .{ .row_offset = 10 });
        _ = try win.printSegment(bot, .{ .row_offset = 11 });
        _ = try win.printSegment(row, .{ .row_offset = 12 });

        try self.vx.render(self.tty.anyWriter());
    }

    fn getLocalMove(self: *Self, game: *Game) !u8 {
        var pos: u8 = undefined;

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
                        if (cursor_pos.y == 0) {
                            cursor_pos.y = 2;
                        } else {
                            cursor_pos.y -|= 1;
                        }
                    }
                    // Go down one square
                    else if (key.matchesAny(&down_keys, .{})) {
                        if (cursor_pos.y == 2) {
                            cursor_pos.y = 0;
                        } else {
                            cursor_pos.y += 1;
                        }
                    }
                    // Go left one square
                    else if (key.matchesAny(&left_keys, .{})) {
                        if (cursor_pos.x == 0) {
                            cursor_pos.x = 2;
                        } else {
                            cursor_pos.x -|= 1;
                        }
                    }
                    // Go right one square
                    else if (key.matchesAny(&right_keys, .{})) {
                        if (cursor_pos.x == 2) {
                            cursor_pos.x = 0;
                        } else {
                            cursor_pos.x += 1;
                        }
                    }
                    // Select a square
                    else if (key.matchesAny(&select_keys, .{})) {
                        pos = cursor_pos.x + 3 * cursor_pos.y;
                        if (!game.board.isPositionOccupied(pos)) {
                            game.board.placeMark(game.current_player, pos);
                            break;
                        }
                    }
                    // N/A
                    else {}
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
            const cur_x = cursor_pos.x * 6 + 4;
            const cur_y = cursor_pos.y * 4 + 3;
            win.showCursor(cur_x, cur_y);
        }

        return pos;
    }

    fn printEndScreen(self: *Self, game: *Game, result: WinState) !void {
        var winner: u8 = undefined;
        var winner_mark: u8 = undefined;

        if (result == WinState.X) {
            winner = 1;
            winner_mark = 'X';
        } else if (result == WinState.O) {
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

        const end: vaxis.Segment = .{ .text = "Press enter to exit." };

        while (true) {
            const win = self.vx.window();
            win.clear();

            try self.printBoard(game);

            // Tie game
            if (result == WinState.Tie) {
                _ = try win.printSegment(tie, .{ .row_offset = 13 });
            }
            // Someone won
            else {
                _ = try win.printSegment(game_won, .{ .row_offset = 13 });
            }

            _ = try win.printSegment(end, .{ .row_offset = 15 });

            const event = self.loop.nextEvent();
            switch (event) {
                .key_press => |key| {
                    if (key.matchesAny(&select_keys, .{})) {
                        break;
                    }
                    // yeet
                    else {}
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak", .{});
        }
    }
    const allocator = gpa.allocator();

    var app = try TuiApp.init(allocator);
    try app.init_loop();
    defer app.deinit();

    var game = Game.init();

    try app.setPlayer(&game, 0);
    if (game.players[0] == PlayerType.Computer) {
        try app.setBotDifficulty(&game, 0);
    }

    try app.setPlayer(&game, 1);
    if (game.players[1] == PlayerType.Computer) {
        try app.setBotDifficulty(&game, 1);
    }

    var game_status: WinState = WinState.None;
    while (game_status == WinState.None) {
        try app.printBoard(&game);

        // const pos = switch (game.players[@as(usize, @intFromEnum(game.current_player))]) {
        //     .Local => {
        //         break app.getLocalMove(&game);
        //     },
        // .Computer => |difficulty| {
        //     switch (difficulty) {
        //         .Easy => {
        //             break 0;
        //         },
        //         .Medium => {
        //             break 0;
        //         },
        //         .Minimax => {
        //             break 0;
        //         },
        //         .Cache => {
        //             break 0;
        //         },
        //         .FastCache => {
        //             break 0;
        //         },
        //         .ABPruning => {
        //             break 0;
        //         },
        //         .PreCache => {
        //             break 0;
        //         },
        //     }
        // },
        // };
        const pos = try app.getLocalMove(&game);
        game.board.placeMark(game.current_player, pos);

        // Waits a second if both players are bots
        // This is so moves are visible. Otherwise, game finishes instantly
        if (game.players[0] == PlayerType.Computer and game.players[1] == PlayerType.Computer) {
            std.time.sleep(1 * std.time.ns_per_s);
        }

        game.nextTurn();

        if (game.turn >= 5) {
            game_status = game.checkForWin();
        }
    }

    try app.printEndScreen(&game, game_status);
}

test "place_x" {
    var b: Board = .{ .x = 0, .o = 0 };
    var i: u8 = 0;

    while (i < 9) : (i += 1) {
        b.placeMark(Mark.X, i);

        try std.testing.expect(b.isPositionOccupied(0));
        try std.testing.expect((b.x & std.math.shl(u9, 1, 8 - i)) != 0);
    }
}

test "place_o" {
    var b: Board = .{ .x = 0, .o = 0 };
    var i: u8 = 0;

    while (i < 9) : (i += 1) {
        b.placeMark(Mark.O, i);

        try std.testing.expect(b.isPositionOccupied(0));
        try std.testing.expect((b.x & std.math.shl(u9, 1, 8 - i)) != 0);
    }
}
