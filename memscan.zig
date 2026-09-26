const std = @import("std");

const RegionInfo = struct {
    start: usize,
    end: usize,

    pub inline fn readSafe(self: @This(), ptr: *const u8) u8 {
        const ptr_usz = @intFromPtr(ptr);
        if (ptr_usz >= self.start and ptr_usz < self.end) {
            return ptr.*;
        }
        return 0;
    }
};

fn getRegionsInfo(io: std.Io, gpa: std.mem.Allocator) !std.ArrayList(RegionInfo) {
    var regions: std.ArrayList(RegionInfo) = .empty;

    const proc_self_dir = try std.Io.Dir.openDirAbsolute(io, "/proc/self", .{});
    defer proc_self_dir.close(io);
    const file = try proc_self_dir.openFile(io, "maps", .{});
    defer file.close(io);

    var buffer: [512]u8 = undefined;

    var reader = file.reader(io, &buffer);
    while (true) {
        var region: RegionInfo = undefined;

        const start_str = (try reader.interface.takeDelimiter('-')) orelse break;
        const start = try std.fmt.parseInt(usize, start_str, 16);
        region.start = start;

        const end_str = (try reader.interface.takeDelimiter(' ')) orelse break;
        const end = try std.fmt.parseInt(usize, end_str, 16);
        region.end = end;

        const prot = (try reader.interface.takeDelimiter(' ')) orelse break;

        const offset = (try reader.interface.takeDelimiter(' ')) orelse break;
        const dev = (try reader.interface.takeDelimiter(' ')) orelse break;
        const inode = (try reader.interface.takeDelimiter(' ')) orelse break;
        const pathname = (try reader.interface.takeDelimiter('\n')) orelse break;
        _ = .{ offset, dev, inode };
        // std.log.debug("{s} {s} {s} {s} {s} {s} {s}", .{ start_str, end_str, prot, offset, dev, inode, pathname });

        if (std.mem.count(u8, pathname, "vvar_vclock") == 0 and prot[0] == 'r') {
            // don't accept non-readable regions
            try regions.append(gpa, region);
        } else {
            // std.log.debug("- skipped", .{});
        }

        // skip everything else
        _ = try reader.interface.takeDelimiter('\n');
    }

    return regions;
}

inline fn loadPadded(vector_length: comptime_int, slice: []const u8) @Vector(vector_length, u8) {
    var v: @Vector(vector_length, u8) = @splat(0);
    @memcpy(@as(*[vector_length]u8, @ptrCast(&v))[0..slice.len], slice);
    return v;
}

const FindPatternError = error{ PatternTooLongForVector, PatternAndWildcardSizeDiffers };
fn findPattern(vector_length: comptime_int, memory: []const u8, pattern: []const u8, wildcards: []const u8) FindPatternError!?usize {
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

test "Pattern scan 1" {
    const expect = std.testing.expect;

    const memory = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05 };
    const pattern = [_]u8{ 0x02, 0x00, 0x04 };
    const wildcards = [_]u8{ 0xff, 0x00, 0xff };
    const index = (try findPattern(32, &memory, &pattern, &wildcards)) orelse 0;
    try expect(index == 1);
}

pub fn main(init: std.process.Init) !void {
    var regions = try getRegionsInfo(init.io, init.gpa);
    defer regions.deinit(init.gpa);

    for (regions.items) |region| {
        std.log.info("{x}-{x} {x}", .{
            region.start,
            region.end,
            region.end - region.start,
        });

        const start_ptr: [*]const u8 = @ptrFromInt(region.start);
        const region_slice = start_ptr[0 .. region.end - region.start];

        const pattern = [_]u8{ 0x69, 0x00, 0x42 };
        const wildcards = [_]u8{ 0xff, 0x00, 0xff };
        if (try findPattern(32, region_slice, &pattern, &wildcards)) |index| {
            std.log.info("FOUND PATTERN {any} {any}", .{
                index,
                region_slice[index],
            });
        }
    }
}
