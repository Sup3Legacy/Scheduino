const std = @import("std");

// Thanks to https://github.com/silversquirl for giving my part of this build script
// to use avr-gcc
pub fn build(b: *std.build.Builder) !void {
    const obj = b.addObject("scheduino", "boot.zig");
    obj.setTarget(std.zig.CrossTarget{
        .cpu_arch = .avr,
        .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega328p },
        .os_tag = .freestanding,
        .abi = .none,
    });

    obj.bundle_compiler_rt = false;
    obj.setBuildMode(.ReleaseSmall);
    obj.strip = true;
    obj.emit_docs = .emit;
    obj.single_threaded = true;
    var link = AvrLinkStep.init(b, "scheduino", &obj.output_path_source);
    link.step.dependOn(&obj.step);
    link.linker_script = "linker.ld";
    _ = link.installRaw("scheduino", .{});

    const bin_path = link.builder.pathJoin(&.{
        link.builder.pathFromRoot(link.builder.cache_root),
        link.output_name,
    });

    const flash_command = blk: {
        var tmp = std.ArrayList(u8).init(b.allocator);
        try tmp.appendSlice("-Uflash:w:");
        try tmp.appendSlice(bin_path);
        try tmp.appendSlice(":e");
        break :blk tmp.toOwnedSlice();
    };

    const upload = b.step("upload", "Upload the code to an Arduino device using avrdude");
    const avrdude = b.addSystemCommand(&.{
        "avrdude",
        "-carduino",
        "-patmega328p",
        "-D",
        "-P",
        "/dev/ttyACM0",
        flash_command,
    });
    upload.dependOn(&avrdude.step);
    avrdude.step.dependOn(&link.step);

    const objdump = b.step("objdump", "Show dissassembly of the code using avr-objdump");
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    objdump.dependOn(&avr_objdump.step);
    avr_objdump.step.dependOn(&link.step);

    const screen = b.step("screen", "Opens the COM-screen");
    const screen_command = b.addSystemCommand(&.{
        "screen",
        "/dev/ttyACM0",
        "19200",
    });
    screen.dependOn(&screen_command.step);
    screen_command.step.dependOn(&avrdude.step);

    const all = b.step("all", "Builds everything, uploads the program and opens the screen.");
    all.dependOn(&screen_command.step);

    b.default_step.dependOn(&link.step);
}

const AvrLinkStep = struct {
    step: std.build.Step,
    builder: *std.build.Builder,
    object: *const std.build.GeneratedFile,
    output_name: []const u8,
    output: std.build.GeneratedFile,
    dummy_artifact: *std.build.LibExeObjStep,

    linker_script: ?[]const u8 = null,

    pub fn init(
        b: *std.build.Builder,
        name: []const u8,
        object: *const std.build.GeneratedFile,
    ) *AvrLinkStep {
        const self = b.allocator.create(AvrLinkStep) catch unreachable;

        const dummy_artifact = std.build.LibExeObjStep.createExecutable(b, name, null);
        dummy_artifact.step = std.build.Step.initNoOp(.custom, name, b.allocator);
        dummy_artifact.step.dependOn(&self.step);
        dummy_artifact.output_path_source = .{ .step = &self.step };

        self.* = .{
            .step = std.build.Step.init(.custom, b.fmt("Link AVR: {s}", .{name}), b.allocator, make),
            .builder = b,
            .object = object,
            .output_name = name,
            .output = .{ .step = &self.step },
            .dummy_artifact = dummy_artifact,
        };
        self.step.dependOn(object.step);

        return self;
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(AvrLinkStep, "step", step);

        const out_path = self.builder.pathJoin(&.{
            self.builder.pathFromRoot(self.builder.cache_root),
            self.output_name,
        });

        var args = std.ArrayList([]const u8).init(self.builder.allocator);
        try args.appendSlice(&.{ "avr-gcc", "-o", out_path });

        if (self.linker_script) |script| {
            const script_path = self.builder.pathFromRoot(script);
            try args.appendSlice(&.{ "-T", script_path });
        }

        try args.append(self.object.getPath());
        _ = try self.builder.execFromStep(args.toOwnedSlice(), &self.step);

        self.output.path = out_path;
        self.dummy_artifact.output_path_source.path = out_path;
    }

    pub fn installRaw(
        self: *AvrLinkStep,
        dest_filename: []const u8,
        opts: std.build.InstallRawStep.CreateOptions,
    ) *std.build.InstallRawStep {
        return self.builder.installRaw(self.dummy_artifact, dest_filename, opts);
    }
};
