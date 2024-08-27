const std = @import("std");
const assert = std.debug.assert;

const vaxis = @import("vaxis");

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
    Remote,

    fn getLocalMove(board: Board) u8 {

    }

    fn getRemoteMove(board: Board) u8 {

    }
};

const PlayerType = enum(u2) {
    Local,
    Computer,
    Remote,

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

    fn getEasyMove(board: Board) u8 {

    }

    fn getMediumMove(board: Board) u8 {

    }

    fn getMinimaxMove(board: Board) u8 {

    }

    fn getCacheMove(board: Board) u8 {

    }

    fn getFastCacheMove(board: Board) u8 {

    }

    fn getABPruningMove(board: Board) u8 {

    }

    fn getPreCacheMove(board: Board) u8 {

    }

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

    fn checkForWin(self: *Self, turn: u8) WinState {
        const winning_boards = [_]u9{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };

        for (winning_boards) |board| {
            if (self.x & board == board) {
                return WinState.X;
            } else if (self.o & board == board) {
                return WinState.O;
            } else {
                continue;
            }
        }

        if (turn == 10) {
            return WinState.Tie;
        } else {
            return WinState.None;
        }
    }

    fn isPositionOccupied(self: *Self, pos: u8) bool {
        return if ((self.x & (1 << 9 - pos)) == 0 or (self.o & (1 << 9 - pos)) == 0) {
            false;
        } else {
            true;
        };
    }

    fn placeMark(self: *Self, pos: u8, mark: Mark) void {
        switch (mark) {
            Mark.X => {
                self.x | (1 << 9 - pos);
            },
            Mark.O => {
                self.o | (1 << 9 - pos);
            },
        }
    }
};

const Game = struct {
    const Self = @This();

    board: Board,
    current_player: Mark,
    players: [2]Player,
    turn: u8,

    fn init(self: *Self) void {
        self.board = .{ .x = 0, .o = 0 };
        self.current_player = Mark.X;
        self.players = undefined;
        self.turn = 1;
    }

    fn getMove(self: *Self) void {
        switch (self.players[self.current_player]) {
            .Local => {
                Player.getLocalMove(self.board);
            },
            .Remote => {
                Player.getRemoteMove(self.board);
            },
            .Computer => {
                switch (self.players[self.current_player].BotDifficulty) {
                    .Easy => {
                        BotDifficulty.getEasyMove(self.board);
                    },
                    .Medium => {
                        BotDifficulty.getMediumMove(self.board);
                    },
                    .Minimax => {
                        BotDifficulty.getMinimaxMove(self.board);
                    },
                    .Cache => {
                        BotDifficulty.getCacheMove(self.board);
                    },
                    .FastCache => {
                        BotDifficulty.getFastCacheMove(self.board);
                    },
                    .ABPruning => {
                        BotDifficulty.getABPruningMove(self.board);
                    },
                    .PreCache => {
                        BotDifficulty.getPreCacheMove(self.board);
                    },
                }
            }
        }
    }
};

pub fn main() !void {
    var game: Game = Game.init();
}

test "win_x" {
    const winning_boards = [_]u9{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };
    var game_board: Board = .{ .x = 0, .o = 0 };

    for (winning_boards) |board| {
        game_board.x = board;

        try std.testing.expectEqual(game_board.checkForWin(5), WinState.X);
    }
}

test "win_o" {
    const winning_boards = [_]u9{ 0b111_000_000, 0b000_111_000, 0b000_000_111, 0b100_100_100, 0b010_010_010, 0b001_001_001, 0b100_010_001, 0b001_010_100 };
    var game_board: Board = .{ .x = 0, .o = 0 };

    for (winning_boards) |board| {
        game_board.o = board;

        try std.testing.expectEqual(game_board.checkForWin(5), WinState.O);
    }
}

test "tie_game" {
    var game_board: Board = .{ .x = 0b001_110_011, .o = 0b110_001_100 };

    try std.testing.expectEqual(game_board.checkForWin(10), WinState.Tie);
}

test "no_winner_yet" {
    var game_board: Board = .{ .x = 0b000_110_001, .o = 0b100_000_100 };

    try std.testing.expectEqual(game_board.checkForWin(5), WinState.None);
}
