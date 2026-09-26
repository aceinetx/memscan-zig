const std = @import("std");

pub const RegionInfo = struct {
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

pub fn getRegionsInfo(io: std.Io, gpa: std.mem.Allocator) !std.ArrayList(RegionInfo) {
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
