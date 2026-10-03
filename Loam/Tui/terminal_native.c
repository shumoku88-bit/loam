/* POSIX terminal mechanics only; supported product platforms are macOS/Linux.
 * Never mix these descriptor reads with stdio reads on the same stdin.
 */
#include <lean/lean.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

LEAN_EXPORT lean_obj_res loam_terminal_read(void) {
    unsigned char bytes[1024];
    ssize_t n;
    do { n = read(STDIN_FILENO, bytes, sizeof(bytes)); } while (n < 0 && errno == EINTR);
    if (n < 0)
        return lean_io_result_mk_error(
            lean_mk_io_error_other_error(errno, lean_mk_string(strerror(errno))));
    lean_object *result = lean_alloc_sarray(1, (size_t)n, (size_t)n);
    if (n > 0) memcpy(lean_sarray_cptr(result), bytes, (size_t)n);
    return lean_io_result_mk_ok(result);
}

LEAN_EXPORT lean_obj_res loam_terminal_size(void) {
    struct winsize size = {0};
    uint64_t packed = 0;
    if ((ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 ||
         ioctl(STDIN_FILENO, TIOCGWINSZ, &size) == 0) && size.ws_row && size.ws_col)
        packed = ((uint64_t)size.ws_row << 32) | size.ws_col;
    return lean_io_result_mk_ok(lean_box_uint64(packed));
}
