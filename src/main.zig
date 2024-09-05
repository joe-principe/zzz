const std = @import("std");
const assert = std.debug.assert;
const vaxis = @import("vaxis");

const up_keys: [4]u21 = .{ 'w', 'k', vaxis.Key.up, vaxis.Key.kp_up };
const down_keys: [4]u21 = .{ 's', 'j', vaxis.Key.down, vaxis.Key.kp_down };
const left_keys: [4]u21 = .{ 'a', 'h', vaxis.Key.left, vaxis.Key.kp_left };
const right_keys: [4]u21 = .{ 'd', 'l', vaxis.Key.right, vaxis.Key.kp_right };
const select_keys: [3]u21 = .{ vaxis.Key.enter, vaxis.Key.kp_enter, vaxis.Key.space };

var rnd: std.rand.Xoshiro256 = undefined;

// Two caches each because when both bots were the same type of cache bot, the
// second player would misinterpret the result and play its worst moves. I could
// probably fix that in code, but I didn't want to spend a bunch of time
// debugging when I could just do this
var cache: [2]std.AutoHashMap(Board, WinState) = undefined;
var fast_cache: [2]std.AutoHashMap(Board, WinState) = undefined;

/// The marks that can be placed on the board.
const Mark = enum(u1) {
    /// Player One
    X,

    /// Player Two
    O,

    comptime {
        for (0..std.enums.values(Mark).len) |i| {
            const res: Mark = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

/// The player type stored by the game struct
// This is done as a union so that the computer player can have a difficulty
// associated with it. There might be a better way to do this, but I'm not aware
// of it
const Player = union(PlayerType) {
    /// Human player
    Local,

    /// Computer player and associated difficulty
    Computer: BotDifficulty,
};

/// The types of players
const PlayerType = enum(u1) {
    /// Human playing at the computer
    Local,

    /// Computer player
    Computer,

    comptime {
        for (0..std.enums.values(PlayerType).len) |i| {
            const res: PlayerType = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

/// The difficulty level of the computer player
const BotDifficulty = enum(u3) {
    /// Easiest difficulty. Makes random, legal moves
    Easy,

    /// Medium difficulty. Makes random, legal moves unless there is a winning
    /// move available
    Medium,

    /// Hard difficulty. Uses the minimax algorithm to find its best possible
    /// moves and randomly selects one
    Minimax,

    /// Hard difficulty. Uses the minimax algorithm to find its best possible
    /// moves and randomly selects one. A hashmap is used to store the results
    /// of each board so the algorithm does not have to be re-run for each move
    Cache,

    /// Hard difficulty. Uses the minimax algorithm to find its best possible
    /// moves and randomly selects one. A hashmap is used to store the results
    /// of each board so the algorithm does not have to be re-run for each move.
    /// Boards are rotated to get equivalent boards, reducing the amount of
    /// caching needed
    FastCache,

    /// Hard difficulty. Uses the minimax algorithm with alpha-beta pruning to
    /// find its best moves and randomly selects one.
    ABPruning,

    comptime {
        for (0..std.enums.values(PlayerType).len) |i| {
            const res: BotDifficulty = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

/// The current result state of the board
const WinState = enum(u2) {
    /// Nobody has won the game
    None,

    /// Player one has won the game
    X,

    /// Player two has won the game
    O,

    /// The game is tied
    Tie,

    /// Converts a minimax score into a WinState
    fn scoreToWinState(
        score: f32,
        player: Mark,
    ) WinState {
        if (score == 10) {
            if (player == Mark.X) return WinState.X else return WinState.O;
        } else if (score == -10) {
            if (player == Mark.X) return WinState.O else return WinState.X;
        }

        return WinState.Tie;
    }

    /// Converts a WinState into a minimax score
    fn winStateToScore(
        result: WinState,
        player: Mark,
    ) f32 {
        if ((result == WinState.X and player == Mark.X) or (result == WinState.O and player == Mark.O)) {
            return 10;
        } else if ((result == WinState.X and player == Mark.O) or (result == WinState.O and player == Mark.X)) {
            return -10;
        }

        return 0;
    }

    comptime {
        for (0..std.enums.values(WinState).len) |i| {
            const res: WinState = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

/// The game board
/// NOTE: Positions on the board are from 0-8, increasing first from left to
/// right then from top to bottom. 0 is top left, 8 is bottom right.
const Board = struct {
    const Self = @This();

    /// The bit-board for player one
    x: u9,

    /// The bit-board for player two
    o: u9,

    // Note: << operator is borked rn (zig 0.13.0), use std.math.shl

    /// Gets the current WinState of the board
    fn getWinState(self: *const Self, turn: u8) WinState {
        const winning_boards = [_]u9{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };

        for (winning_boards) |board| {
            if (self.x & board == board) {
                return WinState.X;
            } else if (self.o & board == board) {
                return WinState.O;
            }
        }

        if (turn == 10) return WinState.Tie;

        return WinState.None;
    }

    /// Checks if a position is occupied
    fn isPositionOccupied(self: *const Self, pos: u8) bool {
        const x_empty: bool = (self.x & std.math.shl(u9, 1, 8 - pos)) == 0;
        const o_empty: bool = (self.o & std.math.shl(u9, 1, 8 - pos)) == 0;

        return if (x_empty and o_empty) false else true;
    }

    /// Places a mark at the given position
    fn placeMark(self: *Self, mark: Mark, pos: u8) void {
        switch (mark) {
            Mark.X => self.x |= std.math.shl(u9, 1, 8 - pos),
            Mark.O => self.o |= std.math.shl(u9, 1, 8 - pos),
        }
    }

    /// Converts the board into a string
    fn toString(self: *Self) [9]u8 {
        var b: [9]u8 = .{ ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' };

        for (0..9) |i| {
            const mask = std.math.shl(u9, 1, 8 - i);

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

    /// Gets all of the legal moves
    /// Modifies the input array to contain the legal moves
    /// Returns the number of legal moves
    fn getLegalMoves(self: *const Self, slice: *[9]u8) usize {
        var i: u8 = 0;
        var j: u8 = 0;

        while (i < 9) : (i += 1) {
            if (!self.isPositionOccupied(i)) {
                slice[j] = i;
                j += 1;
            }
        }

        return j;
    }
};

/// A container for the game state
const Game = struct {
    const Self = @This();

    /// The board
    board: Board,

    /// The turn number. The game begins at turn 1 and goes upto a max of 10
    turn: u8,

    /// The player whose turn it is
    current_player: Mark,

    /// The types of the players
    players: [2]Player,

    /// Sets the default values of the game
    fn init() Game {
        return .{
            .board = .{ .x = 0, .o = 0 },
            .turn = 1,
            .current_player = Mark.X,
            .players = undefined,
        };
    }

    /// Increments the turn number and switches players
    fn nextTurn(self: *Self) void {
        self.turn += 1;
        self.current_player = if (self.current_player == Mark.X) Mark.O else Mark.X;
    }
};

/// The possible events vaxis can receive
const Event = union(enum) {
    /// An input from the keyboard
    key_press: vaxis.Key,

    /// Resizing the window
    winsize: vaxis.Winsize,
};

/// A container for the TUI state
const TuiApp = struct {
    const Self = @This();

    /// The memory allocator
    allocator: std.mem.Allocator,

    /// The teletype terminal
    tty: vaxis.Tty,

    /// The vaxis struct (not sure what this is, lol)
    vx: vaxis.Vaxis,

    /// The event loop
    loop: vaxis.Loop(Event),

    /// Sets the default values of the TUI
    fn init(allocator: std.mem.Allocator) !TuiApp {
        return .{
            .allocator = allocator,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .loop = undefined,
        };
    }

    /// Sets the default values of the TUI event loop and starts the loop
    fn init_loop(self: *Self) !void {
        self.loop = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try self.loop.init();
        try self.loop.start();
    }

    /// Stops the TUI event loop and deinitializes the TUI
    fn deinit(self: *Self) void {
        self.loop.stop();
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    /// Lets the user choose the type of a player
    fn choosePlayer(
        self: *Self,
        game: *Game,
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
                _ = try win.print(&seg, .{ .row_offset = i + 1 });
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
                        game.players[player] = if (selected_option == 0) .Local else Player{ .Computer = undefined };
                        break;
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    /// Lets the user choose the difficulty of a bot player
    fn chooseBotDifficulty(
        self: *Self,
        game: *Game,
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
                    }
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }

    /// Prints out the board
    fn printBoard(self: *Self, game: *Game) !void {
        const b = game.board.toString();

        const win = self.vx.window();

        var player: u8 = undefined;
        var mark: u8 = undefined;
        if (game.current_player == Mark.X) {
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
    }

    /// Gets a move from a local player
    fn getLocalMove(self: *Self, game: *Game) !u8 {
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
                        if (cursor_pos.y == 0) {
                            cursor_pos.y = 2;
                        } else {
                            cursor_pos.y -|= 1;
                        }
                    } else if (key.matchesAny(&down_keys, .{})) {
                        if (cursor_pos.y == 2) {
                            cursor_pos.y = 0;
                        } else {
                            cursor_pos.y += 1;
                        }
                    } else if (key.matchesAny(&left_keys, .{})) {
                        if (cursor_pos.x == 0) {
                            cursor_pos.x = 2;
                        } else {
                            cursor_pos.x -|= 1;
                        }
                    } else if (key.matchesAny(&right_keys, .{})) {
                        if (cursor_pos.x == 2) {
                            cursor_pos.x = 0;
                        } else {
                            cursor_pos.x += 1;
                        }
                    } else if (key.matchesAny(&select_keys, .{})) {
                        pos = cursor_pos.x + 3 * cursor_pos.y;
                        if (!game.board.isPositionOccupied(pos)) {
                            game.board.placeMark(game.current_player, pos);
                            break;
                        }
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
    fn printEndScreen(
        self: *Self,
        game: *Game,
        result: WinState,
    ) !void {
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

        const end: vaxis.Segment = .{ .text = "Press escape to exit." };

        while (true) {
            const win = self.vx.window();
            win.clear();

            if (result == WinState.Tie) {
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
                    if (key.matches(vaxis.Key.escape, .{})) break;
                },
                .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            }
        }
    }
};

/// Gets a move from an easy bot
fn getEasyMove(game: *Game) u8 {
    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    const num = rnd.random().uintLessThan(usize, num_legal);

    return legal_moves[num];
}

/// Gets a move from a medium bot
fn getMediumMove(game: *Game) u8 {
    const b: [9]u8 = game.board.toString();
    const mark: u8 = if (game.current_player == Mark.X) 'X' else 'O';

    // Check the rows for a winning move
    var row: u8 = 0;
    var col: u8 = 0;
    var pos: u8 = 0;
    var sum: u8 = 0;
    while (row < 3) : (row += 1) {
        while (col < 3) : (col += 1) {
            const index: u8 = col + 3 * row;

            if (!game.board.isPositionOccupied(index)) {
                pos = index;
            } else if (b[index] == mark) {
                sum += 1;
            }
        }
        if (sum == 2) return pos;
        col = 0;
        sum = 0;
    }

    // Check the columns for a winning move
    row = 0;
    col = 0;
    while (col < 3) : (col += 1) {
        while (row < 3) : (row += 1) {
            const index: u8 = col + 3 * row;

            if (!game.board.isPositionOccupied(index)) {
                pos = index;
            } else if (b[index] == mark) {
                sum += 1;
            }
        }
        if (sum == 2) return pos;
        row = 0;
        sum = 0;
    }

    // Check the backslash for a winning move
    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        const index: u8 = i * 4;

        if (!game.board.isPositionOccupied(index)) {
            pos = index;
        } else if (b[index] == mark) {
            sum += 1;
        }
    }
    if (sum == 2) return pos;

    // Check the forwardslash for a winning move
    i = 1;
    sum = 0;
    while (i < 4) : (i += 1) {
        const index: u8 = i * 2;

        if (!game.board.isPositionOccupied(index)) {
            pos = index;
        } else if (b[index] == mark) {
            sum += 1;
        }
    }
    if (sum == 2) return pos;

    // Otherwise, just return a random position
    return getEasyMove(game);
}

/// Gets a move from a minimax bot
fn getMinimaxMove(game: *Game) u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == Mark.X) Mark.O else Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        const score: f32 = minimaxScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal));

        if (score > best_score) {
            // If we found a new best move, reset the number of best moves
            // Then add this move to the start of the list
            num_best = 0;
            best_pos[num_best] = legal_moves[i];
            best_score = score;
            num_best += 1;
        } else if (score == best_score) {
            best_pos[num_best] = legal_moves[i];
            num_best += 1;
        }

        // Clear the mark we just placed before the next loop iteration
        if (game.current_player == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    const num = rnd.random().uintLessThan(usize, num_best);

    return best_pos[num];
}

/// Gets the score of a board (for use with getMinimaxMove)
fn minimaxScore(
    board: Board,
    player_to_move: Mark,
    player_to_optimize: Mark,
    turn: u8,
) f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == Mark.X) Mark.O else Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        WinState.None => {},
        WinState.Tie => return 0,
        WinState.X => if (player_to_optimize == Mark.X) return 10 else return -10,
        WinState.O => if (player_to_optimize == Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        const score: f32 = minimaxScore(prediction_board, opponent, player_to_optimize, turn + 1);

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets a move from a cache bot
fn getCacheMove(game: *Game) !u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == Mark.X) Mark.O else Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        var score: f32 = undefined;
        var result: WinState = undefined;
        const player_num = @intFromEnum(game.current_player);

        if (!cache[player_num].contains(prediction_board)) {
            score = try cacheScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal));
            result = WinState.scoreToWinState(score, game.current_player);
            try cache[player_num].put(prediction_board, result);
        } else {
            result = cache[player_num].get(prediction_board) orelse unreachable;
            score = WinState.winStateToScore(result, game.current_player);
        }

        if (score > best_score) {
            // If we found a new best move, reset the number of best moves
            // Then add this move to the start of the list
            num_best = 0;
            best_pos[num_best] = legal_moves[i];
            best_score = score;
            num_best += 1;
        } else if (score == best_score) {
            best_pos[num_best] = legal_moves[i];
            num_best += 1;
        }

        // Clear the mark we just placed before the next loop iteration
        if (game.current_player == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    const num = rnd.random().uintLessThan(usize, num_best);

    return best_pos[num];
}

/// Gets the score of a board (for use with a getCacheMove)
fn cacheScore(
    board: Board,
    player_to_move: Mark,
    player_to_optimize: Mark,
    turn: u8,
) !f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == Mark.X) Mark.O else Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        WinState.None => {},
        WinState.Tie => return 0,
        WinState.X => if (player_to_optimize == Mark.X) return 10 else return -10,
        WinState.O => if (player_to_optimize == Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        var score: f32 = undefined;
        var result: WinState = undefined;
        const player_num = @intFromEnum(player_to_optimize);

        if (!cache[player_num].contains(prediction_board)) {
            score = try cacheScore(prediction_board, opponent, player_to_optimize, turn + 1);
            result = WinState.scoreToWinState(score, player_to_move);
            try cache[player_num].put(prediction_board, result);
        } else {
            result = cache[player_num].get(prediction_board) orelse unreachable;
            score = WinState.winStateToScore(result, player_to_move);
        }

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets a move from a fast cache bot
fn getFastCacheMove(game: *Game) !u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == Mark.X) Mark.O else Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        var score: f32 = undefined;
        var result: WinState = undefined;
        const player_num = @intFromEnum(game.current_player);

        if (!fast_cache[player_num].contains(prediction_board)) {
            score = try fastCacheScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal));
            result = WinState.scoreToWinState(score, game.current_player);

            try fast_cache[player_num].put(prediction_board, result);

            for (getEquivalentRotatedBoards(prediction_board)) |b| {
                try fast_cache[player_num].put(b, result);
            }
        } else {
            result = fast_cache[player_num].get(prediction_board) orelse unreachable;
            score = WinState.scoreFromWinState(result, game.current_player);
        }

        if (score > best_score) {
            // If we found a new best move, reset the number of best moves
            // Then add this move to the start of the list
            num_best = 0;
            best_pos[num_best] = legal_moves[i];
            best_score = score;
            num_best += 1;
        } else if (score == best_score) {
            best_pos[num_best] = legal_moves[i];
            num_best += 1;
        }

        // Clear the mark we just placed before the next loop iteration
        if (game.current_player == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    const num = rnd.random().uintLessThan(usize, num_best);

    return best_pos[num];
}

/// Gets the score of a board (for use with getFastCacheMove)
fn fastCacheScore(
    board: Board,
    player_to_move: Mark,
    player_to_optimize: Mark,
    turn: u8,
) !f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == Mark.X) Mark.O else Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        WinState.None => {},
        WinState.Tie => return 0,
        WinState.X => if (player_to_optimize == Mark.X) return 10 else return -10,
        WinState.O => if (player_to_optimize == Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        var score: f32 = undefined;
        var result: WinState = undefined;
        const player_num = @intFromEnum(player_to_optimize);

        if (!fast_cache[player_num].contains(prediction_board)) {
            score = try fastCacheScore(prediction_board, opponent, player_to_optimize, turn + 1);
            result = WinState.scoreToWinState(score, player_to_move);

            try fast_cache[player_num].put(prediction_board, result);

            for (getEquivalentRotatedBoards(prediction_board)) |b| {
                try fast_cache[player_num].put(b, result);
            }
        } else {
            result = fast_cache[player_num].get(prediction_board) orelse unreachable;
            score = WinState.winStateToScore(result, player_to_move);
        }

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets the 3 boards that are rotationally equivalent to the input board
fn getEquivalentRotatedBoards(board: Board) [3]Board {
    const mask_left: u9 = 0b100_100_100;
    const mask_center: u9 = 0b010_010_010;
    const mask_right: u9 = 0b001_001_001;

    const mask_top: u9 = 0b111_000_000;
    const mask_middle: u9 = 0b000_111_000;
    const mask_bottom: u9 = 0b000_000_111;

    var boards: [3]Board = undefined;

    // Horizontal flip == rotating the board by 90deg CCW
    boards[0].x = ((board.x & mask_left) >> 2) | ((board.x & mask_right) << 2) | (board.x & mask_center);
    boards[0].o = ((board.o & mask_left) >> 2) | ((board.o & mask_right) << 2) | (board.o & mask_center);

    // Horizontal + vertical flip == rotating the board by 180deg
    boards[1].x = ((board.x & mask_left) >> 2) | ((board.x & mask_right) << 2) | (board.x & mask_center);
    boards[1].x = ((board.x & mask_top) >> 6) | ((board.x & mask_bottom) << 6) | (board.x & mask_middle);

    boards[1].o = ((board.o & mask_left) >> 2) | ((board.o & mask_right) << 2) | (board.o & mask_center);
    boards[1].o = ((board.o & mask_top) >> 6) | ((board.o & mask_bottom) << 6) | (board.o & mask_middle);

    // Vertical flip == rotating the board by 270deg CCW
    boards[2].x = ((board.x & mask_top) >> 6) | ((board.x & mask_bottom) << 6) | (board.x & mask_middle);
    boards[2].o = ((board.o & mask_top) >> 6) | ((board.o & mask_bottom) << 6) | (board.o & mask_middle);

    return boards;
}

/// Gets a move from an alpha-beta pruning bot
fn getABPruningMove(game: *Game) u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const alpha = -std.math.inf(f32);
    const beta = std.math.inf(f32);

    const opponent = if (game.current_player == Mark.X) Mark.O else Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        const score: f32 = ABPruningScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal), alpha, beta);

        if (score > best_score) {
            // If we found a new best move, reset the number of best moves
            // Then add this move to the start of the list
            num_best = 0;
            best_pos[num_best] = legal_moves[i];
            best_score = score;
            num_best += 1;
        } else if (score == best_score) {
            best_pos[num_best] = legal_moves[i];
            num_best += 1;
        }

        // Clear the mark we just placed before the next loop iteration
        if (game.current_player == Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    const num = rnd.random().uintLessThan(usize, num_best);

    return best_pos[num];
}

/// Gets the score of a board (for use with getABPruningMove)
fn ABPruningScore(
    board: Board,
    player_to_move: Mark,
    player_to_optimize: Mark,
    turn: u8,
    a: f32,
    b: f32,
) f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    var alpha: f32 = a;
    var beta: f32 = b;

    const opponent = if (player_to_move == Mark.X) Mark.O else Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        WinState.None => {},
        WinState.Tie => return 0,
        WinState.X => if (player_to_optimize == Mark.X) return 10 else return -10,
        WinState.O => if (player_to_optimize == Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: Board = board;

    if (player_to_move == player_to_optimize) {
        for (0..num_legal) |i| {
            prediction_board.placeMark(player_to_move, legal_moves[i]);

            const score: f32 = ABPruningScore(prediction_board, opponent, player_to_optimize, turn + 1, alpha, beta);

            max_score = @max(max_score, score);

            if (max_score > beta) break;

            alpha = @max(alpha, min_score);

            // Clear the mark we just placed before the next loop iteration
            if (player_to_move == Mark.X) {
                prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            } else {
                prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            }
        }
        return max_score;
    } else {
        for (0..num_legal) |i| {
            prediction_board.placeMark(player_to_move, legal_moves[i]);

            const score: f32 = ABPruningScore(prediction_board, opponent, player_to_optimize, turn + 1, alpha, beta);

            min_score = @min(min_score, score);

            if (min_score < alpha) break;

            beta = @min(beta, min_score);

            // Clear the mark we just placed before the next loop iteration
            if (player_to_move == Mark.X) {
                prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            } else {
                prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            }
        }
        return min_score;
    }
}

pub fn main() !void {
    const seed: u64 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
    rnd = std.rand.DefaultPrng.init(seed);

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

    var game: Game = Game.init();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        try app.choosePlayer(&game, i);

        if (game.players[i] == PlayerType.Computer) {
            try app.chooseBotDifficulty(&game, i);

            if (game.players[i].Computer == BotDifficulty.Cache) {
                cache[i] = std.AutoHashMap(Board, WinState).init(allocator);
            } else if (game.players[i].Computer == BotDifficulty.FastCache) {
                fast_cache[i] = std.AutoHashMap(Board, WinState).init(allocator);
            }
        }
    }
    defer cache[0].deinit();
    defer cache[1].deinit();
    defer fast_cache[0].deinit();
    defer fast_cache[1].deinit();

    var game_status: WinState = WinState.None;
    while (game_status == WinState.None) {
        try app.printBoard(&game);

        var pos: u8 = undefined;
        switch (game.players[@as(usize, @intFromEnum(game.current_player))]) {
            .Local => {
                if (app.getLocalMove(&game)) |val| {
                    pos = val;
                } else |err| {
                    std.log.err("Error: {s}\n", .{err});
                    return;
                }
            },
            .Computer => |difficulty| {
                switch (difficulty) {
                    .Easy => pos = getEasyMove(&game),
                    .Medium => pos = getMediumMove(&game),
                    .Minimax => pos = getMinimaxMove(&game),
                    .Cache => {
                        if (getCacheMove(&game)) |val| {
                            pos = val;
                        } else |err| {
                            std.log.err("Error: {s}\n", .{err});
                            return;
                        }
                    },
                    .FastCache => {
                        if (getFastCacheMove(&game)) |val| {
                            pos = val;
                        } else |err| {
                            std.log.err("Error: {s}\n", .{err});
                            return;
                        }
                    },
                    .ABPruning => pos = getABPruningMove(&game),
                }
            },
        }
        game.board.placeMark(game.current_player, pos);

        // Waits a second if both players are bots
        // This is so moves are visible. Otherwise, game finishes instantly
        if (game.players[0] == PlayerType.Computer and game.players[1] == PlayerType.Computer) {
            std.time.sleep(1 * std.time.ns_per_s);
        }

        game.nextTurn();
        game_status = game.board.getWinState(game.turn);
    }

    try app.printEndScreen(&game, game_status);
}

test "place_x" {
    var b: Board = .{ .x = 0, .o = 0 };
    var i: u8 = 0;

    while (i < 9) : (i += 1) {
        b.placeMark(Mark.X, i);

        try std.testing.expect(b.isPositionOccupied(0));
        try std.testing.expect((b.x & std.math.shl(u9, 1, 9 - (i + 1))) != 0);
    }
}

test "place_o" {
    var b: Board = .{ .x = 0, .o = 0 };
    var i: u8 = 0;

    while (i < 9) : (i += 1) {
        b.placeMark(Mark.O, i);

        try std.testing.expect(b.isPositionOccupied(0));
        try std.testing.expect((b.o & std.math.shl(u9, 1, 9 - (i + 1))) != 0);
    }
}

test "win_x" {
    const boards: [8]u9 = .{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };
    var g: Game = Game.init();

    for (boards) |board| {
        g.board.x = board;

        try std.testing.expectEqual(WinState.X, g.board.getWinState(g.turn));
    }
}

test "win_o" {
    const boards: [8]u9 = .{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };
    var g: Game = Game.init();

    for (boards) |board| {
        g.board.o = board;

        try std.testing.expectEqual(WinState.O, g.board.getWinState(g.turn));
    }
}

test "tie_game" {
    const boards: [4]Board = .{
        .{ .x = 0b101_011_010, .o = 0b010_100_101 },
        .{ .x = 0b011_110_001, .o = 0b100_001_110 },
        .{ .x = 0b010_110_101, .o = 0b101_001_010 },
        .{ .x = 0b100_011_110, .o = 0b011_100_001 },
    };
    var g: Game = Game.init();
    g.turn = 10;

    for (boards) |board| {
        g.board = board;

        try std.testing.expectEqual(WinState.Tie, g.board.getWinState(g.turn));
    }
}

test "easy_bot" {
    var g: Game = Game.init();

    try std.testing.expectEqual(false, g.board.isPositionOccupied(getEasyMove(&g)));
}
