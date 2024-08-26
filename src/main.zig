const std = @import("std");
const assert = std.debug.assert;

const vaxis = @import("vaxis");

const Player = enum(u1) {
    X,
    O,

    comptime {
        for (0..std.enums.values(Player).len) |i| {
            const res: Player = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
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
    x: u9,
    o: u9,

    fn checkForWin(self: *Board, turn: u8) WinState {
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

    fn isPositionOccupied(self: *Board, pos: u8) bool {
        return if ((self.x & (1 << 9 - pos)) == 0 or (self.o & (1 << 9 - pos)) == 0) {
            false;
        } else {
            true;
        };
    }

    fn placeMark(self: *Board, pos: u8, player: Player) void {
        switch (player) {
            Player.X => {
                self.x | (1 << 9 - pos);
            },
            Player.O => {
                self.o | (1 << 9 - pos);
            },
        }
    }
};

const Game = struct {
    board: Board,
    current_player: Player,
    player_types: [2]PlayerType,
    turn: u8,

    fn init(self: *Game) void {
        self.board = .{ .x = 0, .o = 0 };
        self.current_player = Player.X;
        self.turn = 1;
    }
};

pub fn main() !void {
    std.debug.print("Hello, world!\n", .{});
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
