const std = @import("std");

const gui = @import("gui");
const tui = @import("tui");
const zzz = @import("game");

pub var should_quit: bool = false;

pub const App = union(enum) {
    const Self = @This();

    gui: gui.GuiApp,
    tui: tui.TuiApp,

    /// Sets the default values of the UI
    pub fn init(allocator: std.mem.Allocator, gui_mode: bool) !App {
        if (gui_mode) {
            return App{ .gui = gui.GuiApp.init(allocator) };
        }
        return App{ .tui = try tui.TuiApp.init(allocator) };
    }

    /// Closes the UI window
    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .gui => gui.GuiApp.deinit(),
            .tui => self.tui.deinit(),
        }
    }

    /// Prints the start menu
    pub fn printStartScreen(self: *Self) !void {
        switch (self.*) {
            .gui => {
                self.gui.printStartScreen();
                should_quit = self.gui.should_quit;
            },
            .tui => {
                try self.tui.printStartScreen();
                should_quit = self.tui.should_quit;
            },
        }
    }

    /// Lets the user choose the type of a player
    pub fn choosePlayer(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) !void {
        switch (self.*) {
            .gui => {
                self.gui.choosePlayer(game, player);
                should_quit = self.gui.should_quit;
            },
            .tui => {
                try self.tui.choosePlayer(game, player);
                should_quit = self.tui.should_quit;
            },
        }
    }

    /// Lets the user choose the difficulty of a bot player
    pub fn chooseBotDifficulty(
        self: *Self,
        game: *zzz.Game,
        player: u8,
    ) !void {
        switch (self.*) {
            .gui => {
                self.gui.chooseBotDifficulty(game, player);
                should_quit = self.gui.should_quit;
            },
            .tui => {
                try self.tui.chooseBotDifficulty(game, player);
                should_quit = self.tui.should_quit;
            },
        }
    }

    /// Prints out the board
    pub fn printBoard(self: *Self, game: *zzz.Game) !void {
        switch (self.*) {
            .gui => {
                try self.gui.printBoard(game);
                should_quit = self.gui.should_quit;
            },
            .tui => {
                try self.tui.printBoard(game);
                should_quit = self.tui.should_quit;
            },
        }
    }

    /// Gets a move from a local player
    pub fn getLocalMove(self: *Self, game: *zzz.Game) !u8 {
        var pos: u8 = undefined;
        switch (self.*) {
            .gui => {
                pos = try self.gui.getLocalMove(game);
                should_quit = self.gui.should_quit;
            },
            .tui => {
                pos = try self.tui.getLocalMove(game);
                should_quit = self.tui.should_quit;
            },
        }

        return pos;
    }

    /// Prints the result screen
    pub fn printEndScreen(
        self: *Self,
        game: *zzz.Game,
        result: zzz.WinState,
    ) !void {
        switch (self.*) {
            .gui => try self.gui.printEndScreen(game, result),
            .tui => try self.tui.printEndScreen(game, result),
        }
    }
};
