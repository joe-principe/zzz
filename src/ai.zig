const std = @import("std");
const assert = std.debug.assert;

const zzz = @import("game");

pub var rnd: std.rand.Xoshiro256 = undefined;

// Two caches each because when both bots were the same type of cache bot, the
// second player would misinterpret the result and play its worst moves. I could
// probably fix that in code, but I didn't want to spend a bunch of time
// debugging when I could just do this
pub var cache: [2]std.AutoHashMap(zzz.Board, zzz.WinState) = undefined;
pub var fast_cache: [2]std.AutoHashMap(zzz.Board, zzz.WinState) = undefined;

/// The difficulty level of the computer player
pub const BotDifficulty = enum(u3) {
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
        for (0..std.enums.values(zzz.PlayerType).len) |i| {
            const res: BotDifficulty = @enumFromInt(i);
            assert(@intFromEnum(res) == i);
        }
    }
};

/// Gets a move from an easy bot
pub fn getEasyMove(game: *zzz.Game) u8 {
    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    const num = rnd.random().uintLessThan(usize, num_legal);

    return legal_moves[num];
}

/// Gets a move from a medium bot
pub fn getMediumMove(game: *zzz.Game) u8 {
    const b: [9]u8 = game.board.toString();
    const mark: u8 = if (game.current_player == zzz.Mark.X) 'X' else 'O';

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
pub fn getMinimaxMove(game: *zzz.Game) u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: zzz.Board = game.board;

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
        if (game.current_player == zzz.Mark.X) {
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
    board: zzz.Board,
    player_to_move: zzz.Mark,
    player_to_optimize: zzz.Mark,
    turn: u8,
) f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        zzz.WinState.None => {},
        zzz.WinState.Tie => return 0,
        zzz.WinState.X => if (player_to_optimize == zzz.Mark.X) return 10 else return -10,
        zzz.WinState.O => if (player_to_optimize == zzz.Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: zzz.Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        const score: f32 = minimaxScore(prediction_board, opponent, player_to_optimize, turn + 1);

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == zzz.Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets a move from a cache bot
pub fn getCacheMove(game: *zzz.Game) !u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: zzz.Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        var score: f32 = undefined;
        var result: zzz.WinState = undefined;
        const player_num = @intFromEnum(game.current_player);

        if (!cache[player_num].contains(prediction_board)) {
            score = try cacheScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal));
            result = zzz.WinState.scoreToWinState(score, game.current_player);
            try cache[player_num].put(prediction_board, result);
        } else {
            result = cache[player_num].get(prediction_board) orelse unreachable;
            score = zzz.WinState.winStateToScore(result, game.current_player);
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
        if (game.current_player == zzz.Mark.X) {
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
    board: zzz.Board,
    player_to_move: zzz.Mark,
    player_to_optimize: zzz.Mark,
    turn: u8,
) !f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        zzz.WinState.None => {},
        zzz.WinState.Tie => return 0,
        zzz.WinState.X => if (player_to_optimize == zzz.Mark.X) return 10 else return -10,
        zzz.WinState.O => if (player_to_optimize == zzz.Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: zzz.Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        var score: f32 = undefined;
        var result: zzz.WinState = undefined;
        const player_num = @intFromEnum(player_to_optimize);

        if (!cache[player_num].contains(prediction_board)) {
            score = try cacheScore(prediction_board, opponent, player_to_optimize, turn + 1);
            result = zzz.WinState.scoreToWinState(score, player_to_move);
            try cache[player_num].put(prediction_board, result);
        } else {
            result = cache[player_num].get(prediction_board) orelse unreachable;
            score = zzz.WinState.winStateToScore(result, player_to_move);
        }

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == zzz.Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets a move from a fast cache bot
pub fn getFastCacheMove(game: *zzz.Game) !u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const opponent = if (game.current_player == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: zzz.Board = game.board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(game.current_player, legal_moves[i]);

        var score: f32 = undefined;
        var result: zzz.WinState = undefined;
        const player_num = @intFromEnum(game.current_player);

        if (!fast_cache[player_num].contains(prediction_board)) {
            score = try fastCacheScore(prediction_board, opponent, game.current_player, @truncate(11 - num_legal));
            result = zzz.WinState.scoreToWinState(score, game.current_player);

            try fast_cache[player_num].put(prediction_board, result);

            for (getEquivalentRotatedBoards(prediction_board)) |b| {
                try fast_cache[player_num].put(b, result);
            }
        } else {
            result = fast_cache[player_num].get(prediction_board) orelse unreachable;
            score = zzz.WinState.winStateToScore(result, game.current_player);
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
        if (game.current_player == zzz.Mark.X) {
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
    board: zzz.Board,
    player_to_move: zzz.Mark,
    player_to_optimize: zzz.Mark,
    turn: u8,
) !f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    const opponent = if (player_to_move == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        zzz.WinState.None => {},
        zzz.WinState.Tie => return 0,
        zzz.WinState.X => if (player_to_optimize == zzz.Mark.X) return 10 else return -10,
        zzz.WinState.O => if (player_to_optimize == zzz.Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: zzz.Board = board;

    for (0..num_legal) |i| {
        prediction_board.placeMark(player_to_move, legal_moves[i]);

        var score: f32 = undefined;
        var result: zzz.WinState = undefined;
        const player_num = @intFromEnum(player_to_optimize);

        if (!fast_cache[player_num].contains(prediction_board)) {
            score = try fastCacheScore(prediction_board, opponent, player_to_optimize, turn + 1);
            result = zzz.WinState.scoreToWinState(score, player_to_move);

            try fast_cache[player_num].put(prediction_board, result);

            for (getEquivalentRotatedBoards(prediction_board)) |b| {
                try fast_cache[player_num].put(b, result);
            }
        } else {
            result = fast_cache[player_num].get(prediction_board) orelse unreachable;
            score = zzz.WinState.winStateToScore(result, player_to_move);
        }

        if (score > max_score) max_score = score;
        if (score < min_score) min_score = score;

        // Clear the mark we just placed before the next loop iteration
        if (player_to_move == zzz.Mark.X) {
            prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        } else {
            prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
        }
    }

    if (player_to_move == player_to_optimize) return max_score;
    return min_score;
}

/// Gets a move from an alpha-beta pruning bot
pub fn getABPruningMove(game: *zzz.Game) u8 {
    var best_score: f32 = -std.math.inf(f32);
    var best_pos: [9]u8 = undefined;
    var num_best: usize = 0;

    const alpha = -std.math.inf(f32);
    const beta = std.math.inf(f32);

    const opponent = if (game.current_player == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    var legal_moves: [9]u8 = undefined;
    const num_legal = game.board.getLegalMoves(&legal_moves);

    // If there is only one legal move, just make it
    if (num_legal == 1) return legal_moves[0];

    var prediction_board: zzz.Board = game.board;

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
        if (game.current_player == zzz.Mark.X) {
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
    board: zzz.Board,
    player_to_move: zzz.Mark,
    player_to_optimize: zzz.Mark,
    turn: u8,
    a: f32,
    b: f32,
) f32 {
    var max_score: f32 = -std.math.inf(f32);
    var min_score: f32 = std.math.inf(f32);

    var alpha: f32 = a;
    var beta: f32 = b;

    const opponent = if (player_to_move == zzz.Mark.X) zzz.Mark.O else zzz.Mark.X;

    const status = board.getWinState(turn);
    switch (status) {
        zzz.WinState.None => {},
        zzz.WinState.Tie => return 0,
        zzz.WinState.X => if (player_to_optimize == zzz.Mark.X) return 10 else return -10,
        zzz.WinState.O => if (player_to_optimize == zzz.Mark.O) return 10 else return -10,
    }

    var legal_moves: [9]u8 = undefined;
    const num_legal = board.getLegalMoves(&legal_moves);

    var prediction_board: zzz.Board = board;

    if (player_to_move == player_to_optimize) {
        for (0..num_legal) |i| {
            prediction_board.placeMark(player_to_move, legal_moves[i]);

            const score: f32 = ABPruningScore(prediction_board, opponent, player_to_optimize, turn + 1, alpha, beta);

            max_score = @max(max_score, score);

            if (max_score > beta) break;

            alpha = @max(alpha, min_score);

            // Clear the mark we just placed before the next loop iteration
            if (player_to_move == zzz.Mark.X) {
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
            if (player_to_move == zzz.Mark.X) {
                prediction_board.x ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            } else {
                prediction_board.o ^= std.math.shl(u9, 1, 8 - legal_moves[i]);
            }
        }
        return min_score;
    }
}

/// Gets the 3 boards that are rotationally equivalent to the input board
fn getEquivalentRotatedBoards(board: zzz.Board) [3]zzz.Board {
    const mask_left: u9 = 0b100_100_100;
    const mask_center: u9 = 0b010_010_010;
    const mask_right: u9 = 0b001_001_001;

    const mask_top: u9 = 0b111_000_000;
    const mask_middle: u9 = 0b000_111_000;
    const mask_bottom: u9 = 0b000_000_111;

    var boards: [3]zzz.Board = undefined;

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
