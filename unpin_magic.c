/* unpin-magic -- feed file's compiled magic database to libmagic from the
 * binary's embedded ZIP instead of a compiled-in xxd array.
 *
 * Pattern 2 (docs/runtime-data.md): magic.mgc rides the single metadata/runtime
 * ZIP at EOF, zstd-compressed (~340 KB vs ~10.6 MB raw -- the db is sparse and
 * compresses ~31x). file's load() pulls it back here via the unpin-vfs self-EOF
 * reader and hands the buffer to magic_load_buffers().
 *
 * Only the EXPLICIT VFS api (unpin_vfs_open) on a virtual marker path is used --
 * served from an anonymous memfd, never through __real_open. So the four
 * __real_* symbols vfs.c's POSIX core references (its pass-through for paths NOT
 * under the mount) are satisfied here by thin libc shims, NOT by `ld --wrap`.
 * That keeps the integration surgical: file's own open()/stat() are untouched,
 * and folding file into a mega multicall adds no global libc interception for
 * the other applets. */
#include "unpin_magic.h"
#include "vfs.h"

#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#define UNPIN_MAGIC_VPATH UNPIN_VFS_ROOT "magic.mgc"

int unpin_load_embedded_magic(void **bufp, size_t *lenp)
{
	int fd = unpin_vfs_open(UNPIN_MAGIC_VPATH, O_RDONLY);
	if (fd < 0)
		return -1;

	struct stat st;
	if (fstat(fd, &st) != 0 || st.st_size <= 0) {
		close(fd);
		return -1;
	}

	size_t len = (size_t)st.st_size;
	unsigned char *buf = malloc(len);
	if (buf == NULL) {
		close(fd);
		return -1;
	}

	size_t off = 0;
	while (off < len) {
		ssize_t r = read(fd, buf + off, len - off);
		if (r <= 0) {
			free(buf);
			close(fd);
			return -1;
		}
		off += (size_t)r;
	}
	close(fd);

	*bufp = buf;
	*lenp = len;
	return 0;
}

/* vfs.c's POSIX core references __real_open/stat/lstat/access for the
 * pass-through of paths outside the mount. `ld --wrap` would resolve those to
 * libc; we don't use --wrap (see the file note above), so define them as direct
 * libc calls. They are never reached for our marker path (memfd), only linked
 * to satisfy the references. */
#ifndef _WIN32
int __real_open(const char *path, int flags, ...)
{
	if (flags & O_CREAT) {
		va_list ap;
		va_start(ap, flags);
		int mode = va_arg(ap, int);
		va_end(ap);
		return open(path, flags, mode);
	}
	return open(path, flags);
}

int __real_stat(const char *path, struct stat *st) { return stat(path, st); }
int __real_lstat(const char *path, struct stat *st) { return lstat(path, st); }
int __real_access(const char *path, int mode) { return access(path, mode); }
#endif
