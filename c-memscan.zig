const c = @cImport({
    @cInclude("errno.h");
    @cInclude("stdint.h");
    @cInclude("stdio.h");
    @cInclude("string.h");
    @cInclude("sys/mman.h");
});

pub fn main() void {
    const map = c.mmap(c.NULL, 4, c.PROT_NONE, c.MAP_PRIVATE | c.MAP_ANONYMOUS, -1, 0);
    if (map == c.MAP_FAILED) return;
    defer _ = c.munmap(map, 4);

    _ = c.printf("map: %p\n", map);

    const file = c.fopen("/proc/self/maps", "r") orelse return;
    defer _ = c.fclose(file);

    var line: [512]u8 = undefined;

    while (c.fgets((&line).ptr, 512, file) != 0) {
        var start: usize = 0;
        var end: usize = 0;
        const permissions: [5]u8 = undefined;

        if (c.sscanf((&line).ptr, "%lx-%lx %4s", &start, &end, &permissions) == 3) {
            _ = c.printf("Region: %lx-%lx\n", start, end);
            _ = c.printf("Size: %lx\n", end - start);
            _ = c.printf("Permissions: %s\n", &permissions);
            // printf("%s", line);
        }
    }
}

// #include <errno.h>
// #include <stdint.h>
// #include <stdio.h>
// #include <string.h>
// #include <sys/mman.h>
//
// int main(void) {
//   void *map = mmap(NULL, 4, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
//   printf("map: %p %s\n", map, strerror(errno));
//
//   uintptr_t address = (uintptr_t)&main;
//   FILE *file = fopen("/proc/self/maps", "r");
//
//   if (!file)
//     return 1;
//
//   char line[512];
//
//   while (fgets(line, sizeof(line), file)) {
//     uintptr_t start, end;
//     char permissions[5];
//
//     if (sscanf(line, "%lx-%lx %4s", &start, &end, permissions) == 3) {
//       printf("Region: %lx-%lx\n", start, end);
//       printf("Size: %lx\n", end - start);
//       printf("Permissions: %s\n", permissions);
//       // printf("%s", line);
//     }
//     /*
//     if (sscanf(line, "%lx-%lx %4s", &start, &end, permissions) == 3 &&
//         start <= address && address < end) {
//       printf("Region: %lx-%lx\n", start, end);
//       printf("Permissions: %s\n", permissions);
//       printf("%s", line);
//       break;
//     }
//     */
//   }
//
//   fclose(file);
//   return 0;
// }
