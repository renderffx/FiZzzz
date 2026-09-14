const std = @import("std");

fn srcMod(b: *std.Build, path: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dest = srcMod(b, "src/dest.zig", target, optimize);
    const html = srcMod(b, "src/html.zig", target, optimize);
    const sched = srcMod(b, "src/sched.zig", target, optimize);
    const tape = srcMod(b, "src/tape.zig", target, optimize);
    const oracle = srcMod(b, "ref/oracle.zig", target, optimize);
    const parse_wire = srcMod(b, "ref/parse_wire.zig", target, optimize);
    const flight = srcMod(b, "src/flight.zig", target, optimize);

    const fizz = srcMod(b, "src/fizz.zig", target, optimize);
    fizz.addImport("dest", dest);
    fizz.addImport("html", html);

    const blotter = srcMod(b, "src/blotter.zig", target, optimize);
    blotter.addImport("dest", dest);
    blotter.addImport("fizz", fizz);
    blotter.addImport("flight", flight);
    blotter.addImport("html", html);
    blotter.addImport("sched", sched);
    blotter.addImport("tape", tape);

    const abort_scene = srcMod(b, "src/abort_scene.zig", target, optimize);
    abort_scene.addImport("fizz", fizz);
    abort_scene.addImport("sched", sched);
    abort_scene.addImport("blotter", blotter);

    const http_mod = srcMod(b, "src/http.zig", target, optimize);

    const router_mod = srcMod(b, "src/router.zig", target, optimize);
    router_mod.addImport("dest", dest);
    router_mod.addImport("fizz", fizz);
    router_mod.addImport("sched", sched);
    router_mod.addImport("blotter", blotter);
    router_mod.addImport("abort_scene", abort_scene);
    router_mod.addImport("http", http_mod);

    const main_mod = srcMod(b, "src/main.zig", target, optimize);
    main_mod.addImport("dest", dest);
    main_mod.addImport("fizz", fizz);
    main_mod.addImport("sched", sched);
    main_mod.addImport("http", http_mod);
    main_mod.addImport("router", router_mod);

    const exe = b.addExecutable(.{
        .name = "fizz",
        .root_module = main_mod,
    });
    b.installArtifact(exe);

    const gen_mod = srcMod(b, "ref/gen.zig", target, optimize);
    gen_mod.addImport("dest", dest);
    gen_mod.addImport("fizz", fizz);
    gen_mod.addImport("flight", flight);
    gen_mod.addImport("sched", sched);
    gen_mod.addImport("blotter", blotter);
    gen_mod.addImport("oracle", oracle);
    gen_mod.addImport("parse_wire", parse_wire);
    const gen_exe = b.addExecutable(.{
        .name = "gen",
        .root_module = gen_mod,
    });
    const run_gen = b.addRunArtifact(gen_exe);
    if (b.args) |args| run_gen.addArgs(args);

    const mut_mod = srcMod(b, "ref/mut.zig", target, optimize);
    mut_mod.addImport("dest", dest);
    mut_mod.addImport("fizz", fizz);
    mut_mod.addImport("flight", flight);
    mut_mod.addImport("sched", sched);
    mut_mod.addImport("parse_wire", parse_wire);
    const mut_exe = b.addExecutable(.{
        .name = "mut",
        .root_module = mut_mod,
    });
    const run_mut = b.addRunArtifact(mut_exe);

    const dump_mod = srcMod(b, "ref/dump.zig", target, optimize);
    dump_mod.addImport("dest", dest);
    dump_mod.addImport("fizz", fizz);
    dump_mod.addImport("flight", flight);
    dump_mod.addImport("sched", sched);
    dump_mod.addImport("parse_wire", parse_wire);
    dump_mod.addImport("blotter", blotter);
    dump_mod.addImport("abort_scene", abort_scene);
    dump_mod.addImport("tape", tape);
    const dump_exe = b.addExecutable(.{
        .name = "dump",
        .root_module = dump_mod,
    });
    b.installArtifact(dump_exe);

    const check_step = b.step("check", "run gen + mutants");
    check_step.dependOn(&run_gen.step);
    check_step.dependOn(&run_mut.step);
}
