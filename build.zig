const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_lib = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";
    const vulkan_headers = b.dependency("vulkan_headers", .{}).path("include");

    const maybe_registry = b.option(std.Build.LazyPath, "registry", "Path to the Vulkan registry");
    if (maybe_registry == null) std.log.info("no vk.xml path provided, pulling from https://github.com/KhronosGroup/Vulkan-Headers", .{});

    const registry = maybe_registry orelse b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan", .{}).artifact("vulkan-zig-generator");
    const vk_gen_cmd = b.addRunArtifact(vk_gen);
    vk_gen_cmd.addFileArg(registry);

    const vulkan = b.addModule("vulkan", .{
        .root_source_file = vk_gen_cmd.addOutputFileArg("vk.zig"),
        .target = target,
        .optimize = optimize,
    });

    const wf = b.addWriteFiles();

    const vma_dep = b.dependency("vma", .{});
    const vma_include = vma_dep.path("include");
    const vma_src = wf.add("vk_mem_alloc.cpp",
        \\#define VMA_IMPLEMENTATION
        \\#include "vk_mem_alloc.h"
    );
    const vma = b.addLibrary(.{
        .name = "vma",
        .root_module = b.createModule(.{
            .optimize = optimize,
            .target = target,
            .link_libcpp = true,
        }),
    });
    vma.addCSourceFile(.{ .file = vma_src });
    vma.addIncludePath(vma_include);
    vma.addIncludePath(vulkan_headers);

    const vma_zig = b.addModule("vma-zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan },
        },
        .link_libc = true,
    });
    vma_zig.addIncludePath(vma_include);
    vma_zig.addIncludePath(vulkan_headers);
    vma_zig.linkLibrary(vma);
    vma_zig.linkSystemLibrary(vulkan_lib, .{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = vma_dep.path("include/vk_mem_alloc.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(vulkan_headers);

    const translate_c_output = b.addInstallFile(translate_c.getOutput(), "vk_mem_alloc.zig");
    b.getInstallStep().dependOn(&translate_c_output.step);
}
