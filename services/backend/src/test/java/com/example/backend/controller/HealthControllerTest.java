package com.example.backend.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for HealthController
 * 
 * These tests verify that health check endpoints work correctly.
 * Health checks are critical for Kubernetes liveness and readiness probes.
 */
@WebMvcTest(HealthController.class)
class HealthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void health_ShouldReturnHealthyStatus() throws Exception {
        mockMvc.perform(get("/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("healthy"))
            .andExpect(jsonPath("$.service").value("backend"));
    }

    @Test
    void ready_ShouldReturnReadyStatus() throws Exception {
        mockMvc.perform(get("/ready"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ready"))
            .andExpect(jsonPath("$.service").value("backend"));
    }
}
