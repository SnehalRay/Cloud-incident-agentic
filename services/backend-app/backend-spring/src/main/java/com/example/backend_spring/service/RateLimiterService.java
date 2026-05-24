package com.example.backend_spring.service;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import java.util.Map;


import java.time.Instant;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class RateLimiterService {


    private static final int MAX_REQUESTS = 2;
    private static final long TIME_WINDOW_MS = 2000; // 2 seconds
    private static final String QUEUE_KEY = "jobs:queue";

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public boolean isAllowed(String clientId){
        String key = "rate_limiter:" + clientId;
        try {
            Long count = redisTemplate.opsForValue().increment(key);
            if (count != null && count == 1) {
                redisTemplate.expire(key, TIME_WINDOW_MS, java.util.concurrent.TimeUnit.MILLISECONDS);
            }
            return count != null && count <= MAX_REQUESTS;
        } catch (Exception e) {
            // Redis unavailable — fail open so legitimate traffic isn't blocked
            log.warn("rate_limiter_redis_unavailable client_id={} error={} — failing open", clientId, e.getMessage());
            return true;
        }
    }

    public void pushViolationJob(String instanceId, String endpoint) {
        try {
            // build the job payload as JSON — the Rust worker will deserialize this
            String payload = objectMapper.writeValueAsString(Map.of(
                    "type", "rate_limit_violation",
                    "instance_id", instanceId,
                    "endpoint", endpoint,
                    "timestamp", Instant.now().toString()
            ));

            // push to the right end of the Redis list — worker consumes from the left (BLPOP)
            redisTemplate.opsForList().rightPush(QUEUE_KEY, payload);
            log.info("rate_limit_job_queued instance_id={} endpoint={}", instanceId, endpoint);
        } catch (Exception e) {
            log.error("rate_limit_job_queue_failed instance_id={} error={}", instanceId, e.getMessage());
        }
    }


}
