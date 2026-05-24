package com.example.backend_spring.controller;

import com.example.backend_spring.config.ShardContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/debug")
@RequiredArgsConstructor
public class DebugController {

    private final JdbcTemplate jdbcTemplate;

    // Kills the JVM so Docker/K8s restarts the container — simulates a crash loop
    @GetMapping("/crash")
    public void crash() {
        log.error("intentional_crash triggered via /api/debug/crash — JVM exiting");
        System.exit(1);
    }

    // Sleeps for `delay` ms before responding — simulates a slow query or blocked thread
    // Firing many concurrent requests exhausts the thread pool and starves normal traffic
    @GetMapping("/slow")
    public Map<String, Object> slow(@RequestParam(defaultValue = "5000") long delay) throws InterruptedException {
        long capped = Math.min(delay, 30_000);
        log.warn("slow_request_start delay_ms={}", capped);
        Thread.sleep(capped);
        log.warn("slow_request_complete delay_ms={}", capped);
        return Map.of("delayed_ms", capped, "status", "ok");
    }

    // Launches `connections` virtual threads each running pg_sleep on the target shard.
    // Saturates that shard's connection pool — normal queries queue up and time out.
    @GetMapping("/overload-shard")
    public Map<String, Object> overloadShard(
            @RequestParam(defaultValue = "0") int shard,
            @RequestParam(defaultValue = "8000") long duration,
            @RequestParam(defaultValue = "15") int connections) {
        long capped = Math.min(duration, 30_000);
        int cappedConns = Math.min(connections, 50);
        log.warn("overload_shard_start shard={} duration_ms={} connections={}", shard, capped, cappedConns);

        for (int i = 0; i < cappedConns; i++) {
            Thread.ofVirtual().start(() -> {
                ShardContext.set(shard);
                try {
                    jdbcTemplate.execute("SELECT pg_sleep(" + (capped / 1000.0) + ")");
                } catch (Exception e) {
                    log.error("overload_shard_query_error shard={} error={}", shard, e.getMessage());
                } finally {
                    ShardContext.clear();
                }
            });
        }

        return Map.of("shard", shard, "connections_launched", cappedConns, "duration_ms", capped);
    }
}
