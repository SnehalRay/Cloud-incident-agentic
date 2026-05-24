package com.example.backend_spring.service;

import com.example.backend_spring.config.ShardContext;
import com.example.backend_spring.model.Item;
import com.example.backend_spring.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.dao.DataAccessException;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ItemService {

    private final ItemRepository itemRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;

    // getAll always reads from shard-1 (default — no context set)
    @Cacheable("items")
    public List<Item> getAll() {
        log.info("cache=miss source=shard-1 fetching all items");
        return itemRepository.findAll();
    }

    @CacheEvict(value = "items", allEntries = true)
    public Item create(Item item) {
        int shard = Math.abs(item.getName().hashCode()) % 2;
        ShardContext.set(shard);
        try {
            item.setCreatedAt(LocalDateTime.now());
            long start = System.currentTimeMillis();
            Item saved = itemRepository.save(item);
            long elapsed = System.currentTimeMillis() - start;
            if (elapsed > 500) {
                log.warn("db_query_slow shard={} elapsed_ms={}", shard, elapsed);
            }
            log.info("item_created id={} name={} shard={} cache=invalidated", saved.getId(), saved.getName(), shard);

            String event = String.format(
                "{\"item_id\":%d,\"name\":\"%s\",\"shard\":%d}",
                saved.getId(), saved.getName().replace("\"", "\\\""), shard
            );
            kafkaTemplate.send("item-events", String.valueOf(saved.getId()), event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.warn("kafka_publish_failed item_id={} error={}", saved.getId(), ex.getMessage());
                    } else {
                        log.info("kafka_event_published item_id={} topic=item-events", saved.getId());
                    }
                });

            return saved;
        } catch (DataAccessException e) {
            log.error("db_write_failed shard={} name={} error={}", shard, item.getName(), e.getMessage());
            throw e;
        } finally {
            ShardContext.clear();
        }
    }
}
