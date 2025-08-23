const std = @import("std");

pub fn buildSDLLib(b: *std.Build, comptime name: []const u8, comptime src_dir: []const u8) !void {
    const dst_lib = "vendor/SDL/lib/lib" ++ name ++ ".a";
    std.fs.cwd().access(dst_lib, .{}) catch {
        const allocator = b.allocator;
        std.fs.cwd().makeDir(src_dir ++ "/build") catch {};

        // Configure with library-specific flags
        var cmake_args = std.ArrayList([]const u8).init(allocator);
        defer cmake_args.deinit();

        try cmake_args.appendSlice(&.{
            "cmake",
            "..",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS=OFF",
        });

        var cmake_config = std.process.Child.init(cmake_args.items, allocator);
        cmake_config.cwd = src_dir ++ "/src";
        std.debug.print("CMAKE CONFIG: {s}\n", .{cmake_config.cwd.?});
        _ = try cmake_config.spawnAndWait();

        // Build only the static library target
        var cmake_build = std.process.Child.init(&.{ "cmake", "--build", "." }, allocator);
        cmake_build.cwd = src_dir ++ "/src";
        std.debug.print("CMAKE BUILD: {s}\n", .{cmake_build.cwd.?});
        _ = try cmake_build.spawnAndWait();

        // Copy the library
        const src_lib = src_dir ++ "/src/lib" ++ name ++ ".a";
        try std.fs.cwd().copyFile(src_lib, std.fs.cwd(), dst_lib, .{});
    };
}

pub fn build(b: *std.Build) void {
    std.fs.cwd().makeDir("vendor/SDL/lib") catch {};
    buildSDLLib(b, "SDL3", "vendor/SDL/SDL3") catch |err| {
        std.log.err("Failed to build SDL3: {}", .{err});
    };

    buildSDLLib(b, "SDL3_image", "vendor/SDL/SDL3_image/") catch |err| {
        std.log.err("Failed to build SDL3_image: {}", .{err});
    };

    buildSDLLib(b, "SDL3_ttf", "vendor/SDL/SDL3_ttf/") catch |err| {
        std.log.err("Failed to build SDL3_ttf: {}", .{err});
    };
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "ogz",
        .root_module = exe_mod,
    });

    exe.addLibraryPath(b.path("vendor/SDL/lib/"));
    exe.addIncludePath(b.path("vendor/SDL/SDL3/include/"));
    exe.addIncludePath(b.path("vendor/SDL/SDL3_image/include/"));
    exe.addIncludePath(b.path("vendor/SDL/SDL3_ttf/include/"));

    exe.linkSystemLibrary("SDL3");
    exe.linkSystemLibrary("SDL3_image");
    exe.linkSystemLibrary("SDL3_ttf");

    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("harfbuzz");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
