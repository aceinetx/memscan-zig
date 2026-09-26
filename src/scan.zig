const std = @import("std");
const RegionInfo = @import("regions.zig").RegionInfo;

inline fn loadPadded(vector_length: comptime_int, slice: []const u8) @Vector(vector_length, u8) {
    var v: @Vector(vector_length, u8) = @splat(0);
    @memcpy(@as(*[vector_length]u8, @ptrCast(&v))[0..slice.len], slice);
    return v;
}

pub const FindPatternError = error{ PatternTooLongForVector, PatternAndWildcardSizeDiffers };
pub fn findPattern(vector_length: comptime_int, memory: []const u8, pattern: []const u8, wildcards: []const u8) FindPatternError!?usize {
    if (pattern.len != wildcards.len) {
        return FindPatternError.PatternAndWildcardSizeDiffers;
    }
    if (pattern.len > vector_length) {
        return FindPatternError.PatternTooLongForVector;
    }

    // Load the pattern into a Vector
    const wildcards_vector = loadPadded(vector_length, wildcards);
    const pattern_vector = loadPadded(vector_length, pattern) & wildcards_vector;

    for (0..memory.len) |i| {
        const start = i;
        var end = i + vector_length;
        if (end >= memory.len) end = memory.len;

        // Load the memory slice into a Vector
        const memory_vector = loadPadded(vector_length, memory[start..end]) & wildcards_vector;

        if (@reduce(.And, memory_vector == pattern_vector)) {
            // std.log.info("pattern: {}", .{pattern_vector});
            // std.log.info("wildcards: {}", .{wildcards_vector});
            // std.log.info("memory: {} {any}", .{ memory_vector, memory[start..end] });
            // std.log.info("found: {}", .{i});
            return start;
        }
    }

    return null;
}

fn findPatternMultithreadedWorker(output: *std.atomic.Value(usize), memory: []const u8, pattern: []const u8, wildcards: []const u8) void {
    const index = findPattern(32, memory, pattern, wildcards) catch |err| {
        std.debug.print("{}", .{err});
        return;
    };

    if (index) |i| {
        output.store(i, .seq_cst);
    }
}

pub fn findPatternMultithreadedRegions(io: std.Io, regions: []RegionInfo, pattern: []const u8, wildcards: []const u8) !usize {
    var g = std.Io.Group.init;
    errdefer g.cancel(io);

    var output = std.atomic.Value(usize).init(0);

    for (regions) |region| {
        const start_ptr: [*]const u8 = @ptrFromInt(region.start);
        const region_slice = start_ptr[0 .. region.end - region.start];
        g.async(io, findPatternMultithreadedWorker, .{
            &output,
            region_slice,
            pattern,
            wildcards,
        });
    }

    try g.await(io);

    return output.load(.seq_cst);
}

test "Pattern scan 1" {
    const expect = std.testing.expect;

    const memory = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05 };
    const pattern = [_]u8{ 0x02, 0x00, 0x04 };
    const wildcards = [_]u8{ 0xff, 0x00, 0xff };
    const index = (try findPattern(32, &memory, &pattern, &wildcards)) orelse 0;
    try expect(index == 1);
}
