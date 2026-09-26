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
        std.log.debug("{s} {s} {s} {s} {s} {s} {s}", .{ start_str, end_str, prot, offset, dev, inode, pathname });

        if (std.mem.count(u8, pathname, "vvar_vclock") == 0 and prot[0] == 'r') {
            // don't accept non-readable regions
            try regions.append(gpa, region);
        } else {
            std.log.debug("- skipped", .{});
        }

        // skip everything else
        _ = try reader.interface.takeDelimiter('\n');
    }

    return regions;
}

fn tryReadRegion(region: RegionInfo) ?usize {
    // const start_ptr: *u8 = @ptrFromInt(region.start);
    // const end_ptr: *u8 = @ptrFromInt(region.end);
    for (region.start..region.end) |i| {
        if (region.readSafe(@ptrFromInt(i)) == 0x69 and region.readSafe(@ptrFromInt(i + 1)) == 0x42) {
            std.log.warn("found 0x6942 at {x}", .{i});
            return i;
        }
    }
    return null;
}

inline fn bitand_array(a: []u8, b: []const u8) void {
    std.debug.assert(a.len == b.len);
    for (0..a.len) |i| {
        a[i] &= b[i];
    }
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    var memory = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05 };
    var pattern = [_]u8{ 0x01, 0x02, 0x03, 0x00, 0x05 };
    const wildcards = [_]u8{ 0xff, 0xff, 0xff, 0x00, 0xff };
    bitand_array(&pattern, &wildcards);
    bitand_array(&memory, &wildcards);
    std.log.debug("{any}", .{memory});
    std.log.debug("{any}", .{pattern});
    std.log.debug("{any}", .{pattern});

    //    var regions = try getRegionsInfo(init.io, init.gpa);

    //    for (regions.items) |region| {
    //        std.log.info("{x}-{x} {x}", .{
    //            region.start,
    //            region.end,
    //            region.end - region.start,
    //        });
    //        if (tryReadRegion(region)) |i| {
    //            const ptr_short = @as([*c]u16, i);
    //            std.log.info("value: {x}", .{ptr_short.*});
    //        }
    //    }

    //    defer regions.deinit(init.gpa);
}
