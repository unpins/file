#ifndef UNPIN_MAGIC_H
#define UNPIN_MAGIC_H

#include <stddef.h>

/* Pull file's compiled magic database (magic.mgc) out of the binary's own
 * embedded ZIP into a fresh malloc'd buffer. Returns 0 on success (*bufp /
 * *lenp set; the caller keeps the buffer for the process lifetime and feeds it
 * to magic_load_buffers), -1 on any failure. See unpin_magic.c. */
int unpin_load_embedded_magic(void **bufp, size_t *lenp);

#endif /* UNPIN_MAGIC_H */
