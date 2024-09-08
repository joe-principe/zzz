const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ai_module = b.createModule(.{
        .root_source_file = b.path("src/ai.zig"),
        .target = target,
        .optimize = optimize,
    });

    const game_module = b.createModule(.{
        .root_source_file = b.path("src/game.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gui_module = b.createModule(.{
        .root_source_file = b.path("src/gui.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add libvaxis module dependency
    const libvaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const tui_module = b.createModule(.{
        .root_source_file = b.path("src/tui.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ui_module = b.createModule(.{
        .root_source_file = b.path("src/ui.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add raylib module dependency
    const raylib_dep = b.dependency("raylib-zig", .{ .target = target, .optimize = optimize });

    const raylib_module = raylib_dep.module("raylib");
    const raygui_module = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    ai_module.addImport("game", game_module);

    game_module.addImport("ai", ai_module);

    gui_module.addImport("game", game_module);
    gui_module.addImport("raylib", raylib_module);
    gui_module.addImport("raygui", raygui_module);

    tui_module.addImport("vaxis", libvaxis.module("vaxis"));
    tui_module.addImport("game", game_module);

    ui_module.addImport("gui", gui_module);
    ui_module.addImport("tui", tui_module);
    ui_module.addImport("game", game_module);

    const exe = b.addExecutable(.{
        .name = "zzz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const build_options = b.addOptions();
    build_options.addOption(bool, "gui", b.option(bool, "gui", "Uses gui mode") orelse false);

    exe.root_module.addImport("ai", ai_module);
    exe.root_module.addImport("game", game_module);
    exe.root_module.addImport("ui", ui_module);

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib_module);
    exe.root_module.addImport("raygui", raygui_module);

    exe.root_module.addOptions("build_options", build_options);

    b.installArtifact(exe);

    // zig build run
    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // zig build test
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
