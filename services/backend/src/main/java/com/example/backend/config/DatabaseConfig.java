package com.example.backend.config;

import com.example.backend.service.SecretsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.util.Map;

@Configuration
@ConditionalOnProperty(name = "spring.datasource.url")
public class DatabaseConfig {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseConfig.class);

    @Autowired(required = false)
    private SecretsService secretsService;

    @Bean
    @Primary
    public Map<String, String> databaseProperties() {
        if (secretsService != null) {
            Map<String, String> credentials = secretsService.getDatabaseCredentials();
            if (!credentials.isEmpty()) {
                logger.info("Using database credentials from AWS Secrets Manager");
                return credentials;
            }
        }
        logger.info("Using database credentials from environment variables");
        return Map.of();
    }
}
