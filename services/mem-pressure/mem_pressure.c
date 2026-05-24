/*
 * mem_pressure.c — allocate memory in chunks until the OOM killer fires.
 *
 * Usage:
 *   mem_pressure [chunk_mb] [limit_mb]
 *
 *   chunk_mb  — how many MB to allocate per step  (default: 10)
 *   limit_mb  — stop early at this many MB         (default: 0 = no limit, keep going)
 *
 * The memset() after every malloc() is mandatory: Linux uses copy-on-write and
 * won't actually map physical pages until they're written. Without it the process
 * appears to allocate memory but the kernel won't account for it, and the OOM
 * killer will never fire.
 *
 * Expected outcomes:
 *   Docker   --memory=64m  → container killed, exit 137 (SIGKILL), OOMKilled=true
 *   K8s      limits.memory → pod terminated, reason=OOMKilled in pod status
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define DEFAULT_CHUNK_MB 10

int main(int argc, char *argv[]) {
    size_t chunk_mb = DEFAULT_CHUNK_MB;
    size_t limit_mb = 0;

    if (argc > 1) chunk_mb = (size_t)atol(argv[1]);
    if (argc > 2) limit_mb = (size_t)atol(argv[2]);

    if (chunk_mb == 0) {
        fprintf(stderr, "error: chunk_mb must be > 0\n");
        return 1;
    }

    size_t chunk_bytes = chunk_mb * 1024 * 1024;
    size_t total_mb    = 0;

    printf("{\"event\":\"mem_pressure_start\",\"chunk_mb\":%zu,\"limit_mb\":%zu}\n",
           chunk_mb, limit_mb);
    fflush(stdout);

    while (1) {
        void *p = malloc(chunk_bytes);
        if (!p) {
            /* malloc itself failed — unusual, means the address space is exhausted
             * before the OOM killer fired (e.g. 32-bit process or ulimit hit) */
            fprintf(stderr,
                "{\"event\":\"mem_pressure_malloc_failed\",\"total_mb\":%zu}\n",
                total_mb);
            fflush(stderr);
            return 1;
        }

        /* Touch every page — forces the kernel to back this allocation
         * with real physical memory so the OOM killer counts it */
        memset(p, 0xFF, chunk_bytes);
        total_mb += chunk_mb;

        printf("{\"event\":\"mem_pressure_step\",\"total_mb\":%zu}\n", total_mb);
        fflush(stdout);

        if (limit_mb > 0 && total_mb >= limit_mb) {
            printf("{\"event\":\"mem_pressure_limit_reached\",\"total_mb\":%zu}\n",
                   total_mb);
            fflush(stdout);
            /* Hold the memory so the process stays at the limit */
            pause();
        }

        /* 200ms between steps — keeps logs readable before the kill arrives */
        usleep(200000);
    }
}
