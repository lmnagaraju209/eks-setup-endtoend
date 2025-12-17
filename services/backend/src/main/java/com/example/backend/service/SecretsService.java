package com.example.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;

import java.util.HashMap;
import java.util.Map;

@Service
public class SecretsService {

    private static final Logger logger = LoggerFactory.getLogger(SecretsService.class);
    private final SecretsManagerClient secretsManagerClient;
    private final ObjectMapper objectMapper;
    
    @Value("${aws.secretsmanager.secret-name:backend-db-credentials}")
    private String secretName;

    public SecretsService(SecretsManagerClient secretsManagerClient) {
        this.secretsManagerClient = secretsManagerClient;
        this.objectMapper = new ObjectMapper();
    }

    public Map<String, String> getDatabaseCredentials() {
        try {
            GetSecretValueRequest request = GetSecretValueRequest.builder()
                    .secretId(secretName)
                    .build();

            GetSecretValueResponse response = secretsManagerClient.getSecretValue(request);
            String secretString = response.secretString();

            JsonNode jsonNode = objectMapper.readTree(secretString);
            Map<String, String> credentials = new HashMap<>();
            
            if (jsonNode.has("host")) {
                credentials.put("host", jsonNode.get("host").asText());
            }
            if (jsonNode.has("username")) {
                credentials.put("username", jsonNode.get("username").asText());
            }
            if (jsonNode.has("password")) {
                credentials.put("password", jsonNode.get("password").asText());
            }
            if (jsonNode.has("database")) {
                credentials.put("database", jsonNode.get("database").asText());
            }

            logger.info("Successfully retrieved database credentials from Secrets Manager");
            return credentials;
        } catch (Exception e) {
            logger.error("Error retrieving secret from Secrets Manager: {}", e.getMessage());
            return new HashMap<>();
        }
    }
}

