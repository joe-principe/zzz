# Zig-Zag-Zoe
Tic-tac-toe TUI game written in Zig

# Features
* TUI Interface
* GUI Interface
* Local PvP
* CPU players with adjustable difficulty
    * Bots can play against other bots, too!

# How To Run
## From Releases
Just run the file like you normally would from your command line.

## From Source
You should be able to simply type `zig build run`. If there are any errors about
missing "vaxis", then run `zig fetch --save git+https://github.com/rockorager/libvaxis`,
and that should add it or something, idk.

# How To Play
Move around using WASD, the arrow keys, hjkl, or the keypad arrows (make sure
numlock is off).

Press enter, space, or keypad enter to select.

# Dependencies
1) [Zig](https://ziglang.org/)
2) [Libvaxis](https://github.com/rockorager/libvaxis)
