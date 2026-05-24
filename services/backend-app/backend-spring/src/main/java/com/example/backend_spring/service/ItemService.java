package com.example.backend_spring.service;

import com.example.backend_spring.config.ShardContext;
import com.example.backend_spring.model.Item;
import com.example.backend_spring.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ItemService {

    private final ItemRepository itemRepository;

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
            Item saved = itemRepository.save(item);
            log.info("item_created id={} name={} shard={} cache=invalidated", saved.getId(), saved.getName(), shard);
            return saved;
        } finally {
            ShardContext.clear();
        }
    }
}
