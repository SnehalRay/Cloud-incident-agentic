package com.example.backend_spring.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.util.Map;

@Configuration
public class DatabaseConfig {

    // HikariCP property binding uses jdbc-url (kebab-case in YAML → jdbcUrl in Java)
    @Bean(name = "shard1DataSource")
    @ConfigurationProperties("app.datasource.shard1")
    DataSource shard1DataSource() {
        return DataSourceBuilder.create().type(HikariDataSource.class).build();
    }

    @Bean(name = "shard2DataSource")
    @ConfigurationProperties("app.datasource.shard2")
    DataSource shard2DataSource() {
        return DataSourceBuilder.create().type(HikariDataSource.class).build();
    }

    // Routing datasource is @Primary — JPA auto-config picks it up transparently.
    // No shard context set → defaults to shard-1.
    @Bean
    @Primary
    DataSource dataSource(
            @Qualifier("shard1DataSource") DataSource shard1,
            @Qualifier("shard2DataSource") DataSource shard2) {
        ShardRoutingDataSource routing = new ShardRoutingDataSource();
        routing.setTargetDataSources(Map.of(0, shard1, 1, shard2));
        routing.setDefaultTargetDataSource(shard1);
        return routing;
    }
}
