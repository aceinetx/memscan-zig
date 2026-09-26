#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>

int main(void) {
  void *map = mmap(NULL, 4, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  printf("map: %p %s\n", map, strerror(errno));

  uintptr_t address = (uintptr_t)&main;
  FILE *file = fopen("/proc/self/maps", "r");

  if (!file)
    return 1;

  char line[512];

  while (fgets(line, sizeof(line), file)) {
    uintptr_t start, end;
    char permissions[5];

    if (sscanf(line, "%lx-%lx %4s", &start, &end, permissions) == 3) {
      printf("Region: %lx-%lx\n", start, end);
      printf("Size: %lx\n", end - start);
      printf("Permissions: %s\n", permissions);
      // printf("%s", line);
    }
    /*
    if (sscanf(line, "%lx-%lx %4s", &start, &end, permissions) == 3 &&
        start <= address && address < end) {
      printf("Region: %lx-%lx\n", start, end);
      printf("Permissions: %s\n", permissions);
      printf("%s", line);
      break;
    }
    */
  }

  fclose(file);
  return 0;
}
