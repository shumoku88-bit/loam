/*
 * EXPERIMENT ONLY: Darwin/APFS syscall witness for a disposable annual root.
 * No production authority, migration, or power-loss durability proof.
 *
 * Build: cc -std=c11 -Wall -Wextra -Werror -o annual-darwin-sync-probe
 *        tools/annual-darwin-sync-probe.c
 * Usage: annual-darwin-sync-probe fsync|fullfsync file|directory PATH
 *
 * The Python harness alone creates PATH under tempfile.TemporaryDirectory.
 * This executable changes no bytes: it only opens/syncs an existing object.
 */
#ifndef __APPLE__
#error This research probe must only be compiled on Darwin
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

static int unsupported(int e) {
  return e == EINVAL || e == ENOTTY || e == ENOSYS
      || e == ENOTSUP || e == EBADF;
}

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: SYNC_API OBJECT_KIND PATH\n");
    return 2;
  }

  const int full = strcmp(argv[1], "fullfsync") == 0;
  if (!full && strcmp(argv[1], "fsync") != 0) {
    fprintf(stderr, "SYNC_BAD_API\n");
    return 2;
  }
  const int directory = strcmp(argv[2], "directory") == 0;
  if (!directory && strcmp(argv[2], "file") != 0) {
    fprintf(stderr, "SYNC_BAD_KIND\n");
    return 2;
  }

  const int flags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
                    | (directory ? O_DIRECTORY : 0);
  const int fd = open(argv[3], flags);
  if (fd < 0) {
    const int e = errno;
    fprintf(stderr, "SYNC_OPEN_ERROR errno=%d reason=%s\n", e, strerror(e));
    return 4;
  }
  struct stat st;
  struct statfs fs;
  if (fstat(fd, &st) != 0 ||
      !(directory ? S_ISDIR(st.st_mode) : S_ISREG(st.st_mode)) ||
      fstatfs(fd, &fs) != 0) {
    fprintf(stderr, "SYNC_TARGET_REJECTED\n");
    close(fd);
    return 4;
  }

  errno = 0;
  const int result = full ? fcntl(fd, F_FULLFSYNC) : fsync(fd);
  const int saved_errno = errno;
  if (close(fd) != 0 && result == 0) {
    fprintf(stderr, "SYNC_CLOSE_ERROR errno=%d\n", errno);
    return 4;
  }
  if (result != 0) {
    fprintf(stderr, "SYNC_SYSCALL_ERROR api=%s kind=%s fstype=%s errno=%d reason=%s\n",
            argv[1], argv[2], fs.f_fstypename, saved_errno,
            strerror(saved_errno));
    return unsupported(saved_errno) ? 3 : 4;
  }
  printf("SYNC_OK api=%s kind=%s fstype=%s\n",
         argv[1], argv[2], fs.f_fstypename);
  return 0;
}
