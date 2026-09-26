const std = @import("std");
const getRegionsInfo = @import("regions.zig").getRegionsInfo;
const scan = @import("scan.zig");

pub fn main(init: std.process.Init) !void {
    var regions = try getRegionsInfo(init.io, init.gpa);
    defer regions.deinit(init.gpa);

    for (regions.items) |region| {
        std.log.info("{x}-{x} {x}", .{
            region.start,
            region.end,
            region.end - region.start,
        });
    }

    const pattern = [_]u8{ 0x69, 0x00, 0x42 };
    const wildcards = [_]u8{ 0xff, 0x00, 0xff };
    const index = try scan.findPatternMultithreadedRegions(init.io, regions.items, &pattern, &wildcards);
    std.log.info("{}", .{index});
}
