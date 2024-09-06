const std = @import("std");

const zzz = @import("game");

const rl = @import("raylib");
const rg = @import("raygui");

const screen_width  = 600;
const screen_height = 800;
const background_color = rl.Color.gray;

pub const GuiApp = struct {
    const Self = @This();

    /// Creates the GUI window
    pub fn init() void {
        rl.initWindow(screen_width, screen_height, "Zig-Zag-Zoe");

        rl.setTargetFPS(60);

        // Make the button font larger
        var font = rl.getFontDefault();
        font.baseSize = 5;
        rg.guiSetFont(font);
    }

    /// Closes the GUI window
    pub fn deinit() void {
        rl.closeWindow();
    }

    /// Prints the start menu
    pub fn printStartScreen() void {

    }

    /// Lets the user choose the type of a player
    pub fn choosePlayer(game: *zzz.Game, player: u8,) void {

    }

    /// Lets the user choose the difficulty of a bot player
    pub fn chooseBotDifficulty(game: *zzz.Game, player: u8,) void {
        var continue_button_pressed = false;
        var continue_button_state = undefined;
        const continue_button_text = "Continue";

        var should_display_select_text = false;

        var selected_difficulty: i32 = -1;
        const difficulty_text = "Easy;Medium;Minimax\nCache;FastCache;Alpha-Beta";

        const bot_num: u8 = if (player == 0) '1' else '2';

        const cb_text = "Choose bot " ++ bot_num;
        const cb_width = rl.measureText(cb_text, 64);
        const cb_offset = @divFloor((screen_width - cb_width), 2);

        const d_text = "Difficulty";
        const d_width = rl.measureText(d_text, 64);
        const d_offset = @divFloor((screen_width - d_width), 2);

        const sd_text = "Please select a difficulty";
        const sd_width = rl.measureText(sd_text, 32);
        const sd_offset = @divFloor((screen_width - sd_width), 2);

        const tc_text = "to continue";
        const tc_width = rl.measureText(tc_text, 32);
        const tc_offset = @divFloor((screen_width - tc_width), 2);

        while (true) {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(background_color);

            rl.drawText(cb_text, cb_offset, 100, 64, rl.Color.white);
            rl.drawText(d_text, d_offset, 170, 64, rl.Color.white);

            if (should_display_select_text) {
                rl.drawText(sd_text, sd_offset, 400, 32, rl.Color.red);
                rl.drawText(tc_text, tc_offset, 440, 32, rl.Color.red);
            }

            continue_button_state = rg.guiButton(.{ .x = 425, .y = 700, .width = 100, .height = 50 }, continue_button_text);
            continue_button_pressed = if (continue_button_state == 0) false else true;

            _ = rg.guiToggleGroup(.{ .x = 75, .y = 500, .width = 150, .height = 50 }, difficulty_text, &selected_difficulty);

            if (continue_button_pressed and (selected_difficulty < 0 or selected_difficulty > 5)) {
                should_display_select_text = true;
            } else {
                game.players[player].Computer = @enumFromInt(selected_difficulty);
                break;
            }
        }
    }

    /// Prints out the board
    pub fn printBoard(game: *zzz.Game) void {
        const b = game.board.toString();

        var player: u8 = undefined;
        var mark: u8 = undefined;
        var player_color: rl.Color = undefined;
        if (game.current_player == zzz.Mark.X) {
            player = '1';
            mark = 'X';
            player_color = rl.Color.blue;
        } else {
            player = '2';
            mark = 'O';
            player_color = rl.Color.yellow;
        }

        const turn: [2]u8 = undefined;
        try std.fmt.bufPrint(turn, "{d}", .{game.turn});

        // Column positions
        const left = 150;
        const center = 300;
        const right = 450;

        // Row positions
        const top = 140;
        const middle = 290;
        const bottom = 440;

        const turn_text = "Turn " ++ turn;

        const p_text = "Player " ++ player ++ ' ';
        const p_width = rl.measureText(p_text, 32);
        const p_offset = 30;

        const lp_offset = p_width + p_offset;

        const mark_offset = rl.measureText('(', 32) + lp_offset;

        const rp_text = ")'s turn";
        const rp_offset = rl.measureText(mark, 32) + mark_offset;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(background_color);

        // Column indicators
        rl.drawText("1", 160, 30, 64, rl.Color.white);
        rl.drawText("2", 300, 30, 64, rl.Color.white);
        rl.drawText("3", 450, 30, 64, rl.Color.white);

        // Row indicators
        rl.drawText("A", 30, 140, 64, rl.Color.white);
        rl.drawText("B", 30, 290, 64, rl.Color.white);
        rl.drawText("C", 30, 440, 64, rl.Color.white);

        // Vertical dividers
        rl.drawRectangle(240, 100, 10, 440, rl.Color.black);
        rl.drawRectangle(390, 100, 10, 440, rl.Color.black);

        // Horizontal dividers
        rl.drawRectangle(100, 240, 440, 10, rl.Color.black);
        rl.drawRectangle(100, 390, 440, 10, rl.Color.black);

        // Draw the marks
        for (0..3) |j| {
            for (0..3) |i| {
                const index = i + 3 * j;
                const x = if (i == 0) left else if (i == 1) center else right;
                const y = if (j == 0) top else if (j == 1) middle else bottom;
                const mark_color = if (b[index] == 'X') rl.Color.blue else rl.Color.red;

                rl.drawText(b[index], x, y, 32, mark_color);
            }
        }

        rl.drawText(turn_text, 30, 575, 32, rl.Color.black);
        
        rl.drawText(p_text, p_offset, 625, 32, player_color);
        rl.drawText('(', lp_offset, 625, 32, rl.Color.black);
        rl.drawText(mark, mark_offset, 625, 32, player_color);
        rl.drawText(rp_text, rp_offset, 625, 32, rl.Color.black);
    }

    /// Gets a move from a local player
    pub fn getLocalMove(game: *zzz.Game) u8 {
        // Column positions
        const left = 100;
        const center = 250;
        const right = 400;

        // Row positions
        const top = 100;
        const middle = 250;
        const bottom = 400;

        const size = 140;

        const squares: [9]rl.Rectangle = .{
            .{ .x = left,   .y = top,    .width = size, .height = size },
            .{ .x = center, .y = top,    .width = size, .height = size },
            .{ .x = right,  .y = top,    .width = size, .height = size },
            .{ .x = left,   .y = middle, .width = size, .height = size },
            .{ .x = center, .y = middle, .width = size, .height = size },
            .{ .x = right,  .y = middle, .width = size, .height = size },
            .{ .x = left,   .y = bottom, .width = size, .height = size },
            .{ .x = center, .y = bottom, .width = size, .height = size },
            .{ .x = right,  .y = bottom, .width = size, .height = size },
        };

        var pos: u8 = undefined;

        while (true) blk: {
            const mouse_pos = rl.getMousePosition();

            rl.beginDrawing();
            defer rl.endDrawing();

            for (squares, 0..) |square, i| {
                const color = if (game.board.isPositionOccupied(i)) rl.Color.red else rl.Color.green;

                if (rl.checkCollisionPointRec(mouse_pos, square)) {
                    rl.drawRectangleRec(square, color);

                    if (!game.board.isPositionOccupied(i) and rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                        pos = i;
                        game.board.placeMark(game.current_player, i);
                        break :blk;
                    }
                }
            }

            GuiApp.printBoard(game);
        }

        return pos;
    }

    /// Prints the result screen
    pub fn printEndScreen(game: *zzz.Game, result: zzz.WinState) void {
        var winner: u8 = undefined;
        const winner_color: rl.Color = undefined;
        if (result == zzz.WinState.X) {
            winner = '1';
            winner_color = rl.Color.blue;
        } else if (result == zzz.WinState.O) {
            winner = '2';
            winner_color = rl.Color.yellow;
        }

        const p_text = "Player " ++ winner;
        const p_width = rl.measureText(p_text, 48);
        const win_offset = p_width + 30;

        const tie_text = "The game is a tie!";
        const end_text = "Press Esc to exit";

        while (true) {
            if (rl.getKeyPressed() == rl.KeyboardKey.key_escape) break;

            rl.beginDrawing();
            defer rl.endDrawing();

            if (result == zzz.WinState.Tie) {
                rl.drawText(tie_text, 30, 680, 48, rl.Color.black);
            } else {
                rl.drawText(p_text, 30, 680, 48, winner_color);
                rl.drawText(" wins!", win_offset, 680, 48, rl.Color.black);
            }

            rl.drawText(end_text, 30, 740, 24, rl.Color.black);

            GuiApp.printBoard(game);
        }
    }
};
