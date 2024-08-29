const std = @import("std");
const assert = std.debug.assert;

const vaxis = @import("vaxis");

const MoveFunc = fn (Board) u8;

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
    const Self = @This();

    x: u9,
    o: u9,

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
    turn: u8,
    current_player: Mark,
    players: [2]Player,
    move_funcs: [2]MoveFunc,

    fn init(self: *Self) void {
        self.board = .{ .x = 0, .o = 0 };
        self.turn = 1;
        self.current_player = Mark.X;
        self.players = undefined;
        self.move_funcs = undefined;
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
};

fn getLocalMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getRemoteMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getEasyMove(board: *Board) u8 {
    const empty_board: u9 = ~(board.x | board.o);
    _ = empty_board;
    @compileError("TODO: Unimplemented");
}

fn getMediumMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getMinimaxMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getCacheMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getFastCacheMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getABPruningMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

fn getPreCacheMove(board: *Board) u8 {
    _ = board;
    @compileError("TODO: Unimplemented");
}

pub fn main() !void {
    var game: Game = Game.init();
    game.init();
}
