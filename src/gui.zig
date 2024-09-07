const std = @import("std");

const zzz = @import("game");

const rl = @import("raylib");
const rg = @import("raygui");

const screen_width = 600;
const screen_height = 800;
const background_color = rl.Color.gray;

pub const GuiApp = struct {
    const Self = @This();

    /// The memory allocator
    allocator: std.mem.Allocator,

    /// A flag for if the app should close
    should_quit: bool,

    /// Creates the GUI window
    pub fn init(allocator: std.mem.Allocator) GuiApp {
        rl.initWindow(screen_width, screen_height, "Zig-Zag-Zoe");

        rl.setTargetFPS(60);

        // Make the button font larger
        var font = rl.getFontDefault();
        font.baseSize = 5;
        rg.guiSetFont(font);

        return .{ .allocator = allocator, .should_quit = false };
    }

    /// Closes the GUI window
    pub fn deinit() void {
        rl.closeWindow();
    }

    /// Prints the start menu
    pub fn printStartScreen(self: *Self) void {
        var font = rl.getFontDefault();
        font.baseSize = 2;
        rg.guiSetFont(font);
        defer {
            font.baseSize = 5;
            rg.guiSetFont(font);
        }

        const zzz_width = rl.measureText("Zig-Zag-Zoe", 80);

        const zig_width = rl.measureText("Zig-", 80);
        const zig_offset = @divFloor((screen_width - zzz_width), 2);

        const zag_width = rl.measureText("Zag-", 80);
        const zag_offset = zig_offset + zig_width;

        const zoe_offset = zag_offset + zag_width;

        var start_button_pressed = false;
        var start_button_state: i32 = undefined;

        while (true) {
            const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
            if (pressed) {
                self.should_quit = true;
                break;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(background_color);

            rl.drawText("Zig", zig_offset, 100, 80, rl.Color.white);
            rl.drawText("Zag", zag_offset, 180, 80, rl.Color.white);
            rl.drawText("Zoe", zoe_offset, 260, 80, rl.Color.white);

            start_button_state = rg.guiButton(.{ .x = 200, .y = 500, .width = 200, .height = 100 }, "Start");
            start_button_pressed = if (start_button_state == 0) false else true;

            if (start_button_pressed) break;
        }
    }

    /// Lets the user choose the type of a player
    pub fn choosePlayer(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) void {
        var continue_button_pressed = false;
        var continue_button_state: i32 = undefined;

        var should_display_select_text = false;

        var selected_option: i32 = -1;

        const c_width = rl.measureText("Choose", 64);
        const c_offset = @divFloor((screen_width - c_width), 2);

        const p_text = if (player == 0) "Player 1" else "Player 2";
        const p_width = rl.measureText(p_text, 64);
        const p_offset = @divFloor((screen_width - p_width), 2);

        const sp_text = "Please select a player type";
        const sp_width = rl.measureText(sp_text, 32);
        const sp_offset = @divFloor((screen_width - sp_width), 2);

        const tc_text = "to continue";
        const tc_width = rl.measureText(tc_text, 32);
        const tc_offset = @divFloor((screen_width - tc_width), 2);

        while (true) {
            const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
            if (pressed) {
                self.should_quit = true;
                break;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(background_color);

            rl.drawText("Choose", c_offset, 100, 64, rl.Color.white);
            rl.drawText(p_text, p_offset, 170, 64, rl.Color.white);

            if (should_display_select_text) {
                rl.drawText(sp_text, sp_offset, 400, 32, rl.Color.red);
                rl.drawText(tc_text, tc_offset, 440, 32, rl.Color.red);
            }

            continue_button_state = rg.guiButton(.{ .x = 430, .y = 700, .width = 100, .height = 50 }, "Continue");
            continue_button_pressed = if (continue_button_state == 0) false else true;

            _ = rg.guiToggleGroup(.{ .x = 75, .y = 550, .width = 226, .height = 50 }, "Human;Computer", &selected_option);

            if (continue_button_pressed and (selected_option < 0 or selected_option > 1)) {
                should_display_select_text = true;
            } else if (continue_button_pressed) {
                game.players[player] = if (selected_option == 0) .Local else zzz.Player{ .Computer = undefined };
                break;
            }
        }
    }

    /// Lets the user choose the difficulty of a bot player
    pub fn chooseBotDifficulty(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) void {
        var continue_button_pressed = false;
        var continue_button_state: i32 = undefined;

        var should_display_select_text = false;

        var selected_difficulty: i32 = -1;
        const difficulty_text = "Easy;Medium;Minimax\nCache;FastCache;Alpha-Beta";

        const cb_text = if (player == 0) "Choose bot 1" else "Choose bot 2";
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
            const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
            if (pressed) {
                self.should_quit = true;
                break;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(background_color);

            rl.drawText(cb_text, cb_offset, 100, 64, rl.Color.white);
            rl.drawText(d_text, d_offset, 170, 64, rl.Color.white);

            if (should_display_select_text) {
                rl.drawText(sd_text, sd_offset, 400, 32, rl.Color.red);
                rl.drawText(tc_text, tc_offset, 440, 32, rl.Color.red);
            }

            continue_button_state = rg.guiButton(.{ .x = 430, .y = 700, .width = 100, .height = 50 }, "Continue");
            continue_button_pressed = if (continue_button_state == 0) false else true;

            _ = rg.guiToggleGroup(.{ .x = 75, .y = 500, .width = 150, .height = 50 }, difficulty_text, &selected_difficulty);

            if (continue_button_pressed and (selected_difficulty < 0 or selected_difficulty > 5)) {
                should_display_select_text = true;
            } else if (continue_button_pressed) {
                game.players[player].Computer = @enumFromInt(selected_difficulty);
                break;
            }
        }
    }

    /// Prints out the board
    pub fn printBoard(self: *Self, game: *zzz.Game) !void {
        const b = game.board.toString();

        var mark: [*:0]const u8 = undefined;
        var player_color: rl.Color = undefined;
        if (game.current_player == zzz.Mark.X) {
            mark = "X";
            player_color = rl.Color.blue;
        } else {
            mark = "O";
            player_color = rl.Color.yellow;
        }

        // Column positions
        const left = 150;
        const center = 300;
        const right = 450;

        // Row positions
        const top = 140;
        const middle = 290;
        const bottom = 440;

        // If it's dumb and it works...
        // Doing this because I don't know how to convert from slices to c
        // strings. TODO: Fix this when you figure it out
        var turn_text: [*:0]const u8 = undefined;
        if (game.turn == 1) {
            turn_text = "Turn 1";
        } else if (game.turn == 2) {
            turn_text = "Turn 2";
        } else if (game.turn == 3) {
            turn_text = "Turn 3";
        } else if (game.turn == 4) {
            turn_text = "Turn 4";
        } else if (game.turn == 5) {
            turn_text = "Turn 5";
        } else if (game.turn == 6) {
            turn_text = "Turn 6";
        } else if (game.turn == 7) {
            turn_text = "Turn 7";
        } else if (game.turn == 8) {
            turn_text = "Turn 8";
        } else if (game.turn == 9) {
            turn_text = "Turn 9";
        } else if (game.turn == 10) {
            turn_text = "Turn 10";
        }

        const p_text = if (game.current_player == zzz.Mark.X) "Player 1 " else "Player 2 ";
        const p_width = rl.measureText(p_text, 32);
        const p_offset = 30;

        const lp_offset = p_width + p_offset;

        const mark_offset = rl.measureText("(", 32) + lp_offset;

        const rp_text = ")'s turn";
        const rp_offset = rl.measureText(mark, 32) + mark_offset;

        const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
        if (pressed) self.should_quit = true;

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

                const x: i32 = if (i == 0) left else if (i == 1) center else right;
                const y: i32 = if (j == 0) top else if (j == 1) middle else bottom;

                var m: [*:0]const u8 = undefined;
                var mark_color: rl.Color = undefined;
                if (b[index] == 'X') {
                    m = "X";
                    mark_color = rl.Color.blue;
                } else if (b[index] == 'O') {
                    m = "O";
                    mark_color = rl.Color.yellow;
                } else {
                    m = " ";
                    mark_color = rl.Color.black;
                }

                rl.drawText(m, x, y, 64, mark_color);
            }
        }

        // Turn n
        rl.drawText(turn_text, 30, 575, 32, rl.Color.black);

        // Player 1 (X)'s turn
        // Player 2 (O)'s turn
        rl.drawText(p_text, p_offset, 625, 32, player_color); // Player 1/2
        rl.drawText("(", lp_offset, 625, 32, rl.Color.black); // (
        rl.drawText(mark, mark_offset, 625, 32, player_color); // X/O
        rl.drawText(rp_text, rp_offset, 625, 32, rl.Color.black); // )'s turn
    }

    /// Gets a move from a local player
    pub fn getLocalMove(self: *Self, game: *zzz.Game) !u8 {
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
            .{ .x = left, .y = top, .width = size, .height = size },
            .{ .x = center, .y = top, .width = size, .height = size },
            .{ .x = right, .y = top, .width = size, .height = size },
            .{ .x = left, .y = middle, .width = size, .height = size },
            .{ .x = center, .y = middle, .width = size, .height = size },
            .{ .x = right, .y = middle, .width = size, .height = size },
            .{ .x = left, .y = bottom, .width = size, .height = size },
            .{ .x = center, .y = bottom, .width = size, .height = size },
            .{ .x = right, .y = bottom, .width = size, .height = size },
        };

        var pos: u8 = undefined;

        var should_loop = true;
        while (should_loop) {
            const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
            if (pressed) {
                self.should_quit = true;
                break;
            }

            const mouse_pos = rl.getMousePosition();
            const clicked = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left) or rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left) or rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left);

            rl.beginDrawing();
            defer rl.endDrawing();

            var i: u8 = 0;
            for (squares) |square| {
                const color = if (game.board.isPositionOccupied(i)) rl.Color.red else rl.Color.green;

                if (rl.checkCollisionPointRec(mouse_pos, square)) {
                    rl.drawRectangleRec(square, color);

                    if (!game.board.isPositionOccupied(i) and clicked) {
                        game.board.placeMark(game.current_player, i);
                        pos = i;
                        should_loop = false;
                        break;
                    }
                }

                i += 1;
            }

            try self.printBoard(game);
        }

        return pos;
    }

    /// Prints the result screen
    pub fn printEndScreen(self: *Self, game: *zzz.Game, result: zzz.WinState) !void {
        var winner: u8 = undefined;
        var winner_color: rl.Color = undefined;
        if (result == zzz.WinState.X) {
            winner = 1;
            winner_color = rl.Color.blue;
        } else if (result == zzz.WinState.O) {
            winner = 2;
            winner_color = rl.Color.yellow;
        }

        const p_text = if (result == zzz.WinState.X) "Player 1" else "Player 2";
        const p_width = rl.measureText(p_text, 48);
        const win_offset = p_width + 30;

        const tie_text = "The game is a tie!";
        const end_text = "Press Esc to exit";

        while (true) {
            const pressed = rl.isKeyDown(rl.KeyboardKey.key_escape) or rl.isKeyPressed(rl.KeyboardKey.key_escape) or rl.isKeyReleased(rl.KeyboardKey.key_escape);
            if (pressed) {
                self.should_quit = true;
                break;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(background_color);

            if (result == zzz.WinState.Tie) {
                rl.drawText(tie_text, 30, 680, 48, rl.Color.black);
            } else {
                rl.drawText(p_text, 30, 680, 48, winner_color);
                rl.drawText(" wins!", win_offset, 680, 48, rl.Color.black);
            }

            rl.drawText(end_text, 30, 740, 24, rl.Color.black);

            try self.printBoard(game);
        }
    }
};
