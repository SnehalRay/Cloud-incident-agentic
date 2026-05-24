/*
 * tc_fault.c — inject/remove tc-netem rules into a running container's
 * network namespace without stopping it.
 *
 * Usage:
 *   tc_fault add  <container> [--delay <ms>] [--jitter <ms>] [--loss <pct>]
 *   tc_fault del  <container>
 *   tc_fault show <container>
 *
 * Must run as root (needs CAP_SYS_ADMIN + CAP_NET_ADMIN).
 * Expects to be built inside a privileged Docker container with --pid=host
 * so that /proc/<pid>/ns/net is reachable.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sched.h>
#include <sys/wait.h>
#include <sys/types.h>

#define TC_PATH   "/sbin/tc"
#define NETDEV    "eth0"
#define MAX_ARGV  32
#define PID_BUF   32
#define NS_BUF    64
#define CMD_BUF   256

/* ── helpers ──────────────────────────────────────────────────────────── */

static pid_t container_pid(const char *name) {
    char cmd[CMD_BUF];
    snprintf(cmd, sizeof(cmd),
             "docker inspect --format='{{.State.Pid}}' %s 2>/dev/null", name);

    FILE *fp = popen(cmd, "r");
    if (!fp) {
        fprintf(stderr, "error: popen failed: %s\n", strerror(errno));
        return -1;
    }

    char buf[PID_BUF] = {0};
    if (!fgets(buf, sizeof(buf), fp)) {
        pclose(fp);
        fprintf(stderr, "error: docker inspect returned nothing for '%s'\n", name);
        return -1;
    }
    pclose(fp);

    pid_t pid = (pid_t)atoi(buf);
    if (pid <= 0) {
        fprintf(stderr, "error: invalid PID '%s' for container '%s'\n", buf, name);
        return -1;
    }
    return pid;
}

/* Enter the network namespace of <pid>, then exec argv[0..]. */
static int run_in_netns(pid_t pid, char *const argv[]) {
    char ns_path[NS_BUF];
    snprintf(ns_path, sizeof(ns_path), "/proc/%d/ns/net", (int)pid);

    pid_t child = fork();
    if (child < 0) {
        fprintf(stderr, "error: fork: %s\n", strerror(errno));
        return -1;
    }

    if (child == 0) {
        /* ── child: enter network namespace, exec tc ── */
        int fd = open(ns_path, O_RDONLY | O_CLOEXEC);
        if (fd < 0) {
            fprintf(stderr, "error: open %s: %s\n", ns_path, strerror(errno));
            _exit(1);
        }
        if (setns(fd, CLONE_NEWNET) < 0) {
            fprintf(stderr, "error: setns(%s): %s\n", ns_path, strerror(errno));
            close(fd);
            _exit(1);
        }
        close(fd);
        execvp(argv[0], argv);
        fprintf(stderr, "error: execvp %s: %s\n", argv[0], strerror(errno));
        _exit(1);
    }

    /* ── parent: wait for child ── */
    int status;
    if (waitpid(child, &status, 0) < 0) {
        fprintf(stderr, "error: waitpid: %s\n", strerror(errno));
        return -1;
    }
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return -1;
}

/* ── subcommands ──────────────────────────────────────────────────────── */

static int cmd_add(const char *container,
                   int delay_ms, int jitter_ms, double loss_pct) {
    pid_t pid = container_pid(container);
    if (pid < 0) return 1;

    /* Build: tc qdisc replace dev eth0 root netem delay Xms [jitter Xms] [loss X%] */
    char *argv[MAX_ARGV];
    int   i = 0;

    char delay_str[32], jitter_str[32], loss_str[32];
    snprintf(delay_str,  sizeof(delay_str),  "%dms", delay_ms);
    snprintf(jitter_str, sizeof(jitter_str), "%dms", jitter_ms);
    snprintf(loss_str,   sizeof(loss_str),   "%.2f%%", loss_pct);

    argv[i++] = TC_PATH;
    argv[i++] = "qdisc";
    argv[i++] = "replace";
    argv[i++] = "dev";
    argv[i++] = NETDEV;
    argv[i++] = "root";
    argv[i++] = "netem";

    if (delay_ms > 0) {
        argv[i++] = "delay";
        argv[i++] = delay_str;
        if (jitter_ms > 0) {
            argv[i++] = jitter_str;
            argv[i++] = "distribution";
            argv[i++] = "normal"; /* realistic bell-curve jitter */
        }
    }
    if (loss_pct > 0.0) {
        argv[i++] = "loss";
        argv[i++] = loss_str;
    }
    argv[i] = NULL;

    printf("Applying netem to container '%s' (PID %d) on %s\n",
           container, (int)pid, NETDEV);
    if (delay_ms  > 0) printf("  delay  : %dms", delay_ms);
    if (jitter_ms > 0) printf(" ± %dms (normal)", jitter_ms);
    if (delay_ms  > 0) printf("\n");
    if (loss_pct  > 0) printf("  loss   : %.2f%%\n", loss_pct);

    int rc = run_in_netns(pid, argv);
    if (rc == 0) printf("Done.\n");
    else         fprintf(stderr, "tc qdisc replace failed (exit %d)\n", rc);
    return rc;
}

static int cmd_del(const char *container) {
    pid_t pid = container_pid(container);
    if (pid < 0) return 1;

    char *argv[] = {
        TC_PATH, "qdisc", "del", "dev", NETDEV, "root", NULL
    };

    printf("Removing netem from container '%s' (PID %d)\n",
           container, (int)pid);
    int rc = run_in_netns(pid, argv);
    if (rc == 0) printf("Done.\n");
    else         fprintf(stderr, "tc qdisc del failed (exit %d) — was netem active?\n", rc);
    return rc;
}

static int cmd_show(const char *container) {
    pid_t pid = container_pid(container);
    if (pid < 0) return 1;

    char *argv[] = {
        TC_PATH, "qdisc", "show", "dev", NETDEV, NULL
    };

    printf("tc qdisc show for container '%s' (PID %d):\n",
           container, (int)pid);
    return run_in_netns(pid, argv);
}

/* ── argument parsing ─────────────────────────────────────────────────── */

static void usage(void) {
    fprintf(stderr,
        "Usage:\n"
        "  tc_fault add  <container> [--delay <ms>] [--jitter <ms>] [--loss <pct>]\n"
        "  tc_fault del  <container>\n"
        "  tc_fault show <container>\n"
        "\n"
        "Examples:\n"
        "  tc_fault add  incident-lab-postgres-shard-1 --delay 200 --jitter 50 --loss 1.0\n"
        "  tc_fault show incident-lab-postgres-shard-1\n"
        "  tc_fault del  incident-lab-postgres-shard-1\n"
    );
}

int main(int argc, char *argv[]) {
    if (argc < 3) { usage(); return 1; }

    const char *subcmd    = argv[1];
    const char *container = argv[2];

    if (strcmp(subcmd, "del") == 0)  return cmd_del(container);
    if (strcmp(subcmd, "show") == 0) return cmd_show(container);

    if (strcmp(subcmd, "add") != 0) {
        fprintf(stderr, "error: unknown subcommand '%s'\n", subcmd);
        usage();
        return 1;
    }

    /* parse optional flags for 'add' */
    int    delay_ms  = 100;  /* defaults */
    int    jitter_ms = 0;
    double loss_pct  = 0.0;

    for (int i = 3; i < argc; i++) {
        if (strcmp(argv[i], "--delay") == 0 && i + 1 < argc) {
            delay_ms = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--jitter") == 0 && i + 1 < argc) {
            jitter_ms = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--loss") == 0 && i + 1 < argc) {
            loss_pct = atof(argv[++i]);
        } else {
            fprintf(stderr, "error: unknown argument '%s'\n", argv[i]);
            usage();
            return 1;
        }
    }

    return cmd_add(container, delay_ms, jitter_ms, loss_pct);
}
