const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // GUI executable — requires raylib headers and library installed on the system.
    // Install via: sudo apt install libraylib-dev (Ubuntu) or build from source.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    exe_mod.linkSystemLibrary("raylib", .{});
    exe_mod.linkSystemLibrary("GL", .{});
    exe_mod.linkSystemLibrary("m", .{});
    exe_mod.linkSystemLibrary("pthread", .{});
    exe_mod.linkSystemLibrary("dl", .{});
    exe_mod.linkSystemLibrary("rt", .{});
    exe_mod.linkSystemLibrary("X11", .{});

    const exe = b.addExecutable(.{
        .name = "paintdotzig",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run Paint.Zig");
    run_step.dependOn(&run_cmd.step);

    // Tests — only compile the modules that do NOT depend on raylib.
    // This keeps CI happy on headless machines without GPU / X11.
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_exe = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
