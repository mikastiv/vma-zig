const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const maybe_registry = b.option(std.Build.LazyPath, "registry", "Path to the Vulkan registry");
    if (maybe_registry == null) std.log.warn("no vk.xml path provided, pulling from https://github.com/KhronosGroup/Vulkan-Headers", .{});

    const registry = maybe_registry orelse b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan", .{}).artifact("vulkan-zig-generator");
    const vk_gen_cmd = b.addRunArtifact(vk_gen);
    vk_gen_cmd.addFileArg(registry);

    const vulkan_lib = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";
    const vulkan_sdk = b.graph.env_map.get("VK_SDK_PATH") orelse @panic("VK_SDK_PATH is not set");

    const vulkan_memory_allocator = b.dependency("vulkan_memory_allocator", .{});
    const vma_header = vulkan_memory_allocator.path("include/vk_mem_alloc.h");
    _ = b.addInstallFile(vma_header, ".");

    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(vma_header, "vk_mem_alloc.h");
    const vma_src = wf.add("vk_mem_alloc.cpp",
        \\#define VMA_IMPLEMENTATION
        \\#include "vk_mem_alloc.h"
    );

    const vma = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    vma.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "include" }) });
    vma.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "lib" }) });
    vma.linkSystemLibrary(vulkan_lib, .{});
    vma.addCSourceFile(.{ .file = vma_src });

    const vulkan = b.addModule("vulkan", .{
        .root_source_file = vk_gen_cmd.addOutputFileArg("vk.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vma_zig = b.addModule("vma-zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    vma_zig.addImport("vulkan", vulkan);
    vma_zig.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "include" }) });
    vma_zig.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "lib" }) });
    vma_zig.linkLibrary(b.addLibrary(.{ .name = "vma", .root_module = vma }));
}
