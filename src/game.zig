const std = @import("std");
const assert = std.debug.assert;

const ai = @import("ai");

/// The marks that can be placed on the board.
pub const Mark = enum(u1) {
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
pub const Player = union(PlayerType) {
    /// Human player
    Local,

    /// Computer player and associated difficulty
    Computer: ai.BotDifficulty,
};

/// The type of a player
pub const PlayerType = enum(u1) {
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

/// The current result state of the board
pub const WinState = enum(u2) {
    /// Nobody has won the game
    None,

    /// Player one has won the game
    X,

    /// Player two has won the game
    O,

    /// The game is tied
    Tie,

    /// Converts a minimax score into a WinState
    pub fn scoreToWinState(
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
    pub fn winStateToScore(
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
pub const Board = struct {
    const Self = @This();

    /// The bit-board for player one
    x: u9,

    /// The bit-board for player two
    o: u9,

    // Note: << operator is borked rn (zig 0.13.0), use std.math.shl

    /// Gets the current WinState of the board
    pub fn getWinState(self: *const Self, turn: u8) WinState {
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
    pub fn isPositionOccupied(self: *const Self, pos: u8) bool {
        const x_empty: bool = (self.x & std.math.shl(u9, 1, 8 - pos)) == 0;
        const o_empty: bool = (self.o & std.math.shl(u9, 1, 8 - pos)) == 0;

        return if (x_empty and o_empty) false else true;
    }

    /// Places a mark at the given position
    pub fn placeMark(self: *Self, mark: Mark, pos: u8) void {
        switch (mark) {
            Mark.X => self.x |= std.math.shl(u9, 1, 8 - pos),
            Mark.O => self.o |= std.math.shl(u9, 1, 8 - pos),
        }
    }

    /// Converts the board into a string
    pub fn toString(self: *Self) [9]u8 {
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
    pub fn getLegalMoves(self: *const Self, legal: *[9]u8) usize {
        var i: u8 = 0;
        var j: u8 = 0;

        while (i < 9) : (i += 1) {
            if (!self.isPositionOccupied(i)) {
                legal[j] = i;
                j += 1;
            }
        }

        return j;
    }
};

/// A container for the game state
pub const Game = struct {
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
    pub fn init() Game {
        return .{
            .board = .{ .x = 0, .o = 0 },
            .turn = 1,
            .current_player = Mark.X,
            .players = undefined,
        };
    }

    /// Increments the turn number and switches players
    pub fn nextTurn(self: *Self) void {
        self.turn += 1;
        self.current_player = if (self.current_player == Mark.X) Mark.O else Mark.X;
    }
};

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

    try std.testing.expectEqual(false, g.board.isPositionOccupied(ai.getEasyMove(&g)));
}
