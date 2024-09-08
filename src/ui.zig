const std = @import("std");

const gui = @import("gui");
const tui = @import("tui");
const zzz = @import("game");

/// Allows the user to quit the game at any time from any screen
// Idk if there's a more elegant solution to this, but this works nicely so idc
pub var should_quit: bool = false;

/// An interface for the game's UI
// Done as a tagged union to allow the game to operate in either GUI or TUI mode
// without much additional code (other than what's in this struct, ofc)
pub const App = union(enum) {
    const Self = @This();

    /// App in GUI Mode
    gui: gui.GuiApp,

    /// App in TUI Mode
    tui: tui.TuiApp,

    /// Sets the default values of the UI
    pub fn init(allocator: std.mem.Allocator, gui_mode: bool) !App {
        if (gui_mode) return .{ .gui = gui.GuiApp.init(allocator) };
        return .{ .tui = try tui.TuiApp.init(allocator) };
    }

    /// Sets up the chosen UI mode
    // This is mostly a convenience thing to allow for creating the TUI loop
    // without having a weird line of TUI only code within main.zig
    pub fn setup(self: *Self) !void {
        switch (self.*) {
            .gui => gui.GuiApp.setup(),
            .tui => try self.tui.setup(),
        }
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
