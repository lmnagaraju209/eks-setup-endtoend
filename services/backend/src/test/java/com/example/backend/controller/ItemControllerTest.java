package com.example.backend.controller;

import com.example.backend.model.Item;
import com.example.backend.repository.ItemRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for ItemController
 * 
 * These tests demonstrate:
 * - Testing REST API endpoints
 * - Mocking dependencies (ItemRepository)
 * - Verifying HTTP status codes and response bodies
 * - Testing CRUD operations
 */
@WebMvcTest(ItemController.class)
class ItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ItemRepository itemRepository;

    @Autowired
    private ObjectMapper objectMapper;

    private Item testItem;

    @BeforeEach
    void setUp() {
        testItem = new Item(1L, "Test Item", "Test Description");
    }

    @Test
    void getAllItems_ShouldReturnListOfItems() throws Exception {
        // Arrange
        List<Item> items = Arrays.asList(
            testItem,
            new Item(2L, "Item 2", "Description 2")
        );
        when(itemRepository.findAll()).thenReturn(items);

        // Act & Assert
        mockMvc.perform(get("/api/v1/items"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray())
            .andExpect(jsonPath("$[0].id").value(1L))
            .andExpect(jsonPath("$[0].name").value("Test Item"))
            .andExpect(jsonPath("$[1].id").value(2L));

        verify(itemRepository, times(1)).findAll();
    }

    @Test
    void getItem_WhenItemExists_ShouldReturnItem() throws Exception {
        // Arrange
        when(itemRepository.findById(1L)).thenReturn(Optional.of(testItem));

        // Act & Assert
        mockMvc.perform(get("/api/v1/items/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.name").value("Test Item"))
            .andExpect(jsonPath("$.description").value("Test Description"));

        verify(itemRepository, times(1)).findById(1L);
    }

    @Test
    void getItem_WhenItemNotFound_ShouldReturn404() throws Exception {
        // Arrange
        when(itemRepository.findById(999L)).thenReturn(Optional.empty());

        // Act & Assert
        mockMvc.perform(get("/api/v1/items/999"))
            .andExpect(status().isNotFound());

        verify(itemRepository, times(1)).findById(999L);
    }

    @Test
    void createItem_ShouldReturnCreatedItem() throws Exception {
        // Arrange
        Item newItem = new Item(null, "New Item", "New Description");
        Item savedItem = new Item(1L, "New Item", "New Description");
        when(itemRepository.save(any(Item.class))).thenReturn(savedItem);

        // Act & Assert
        mockMvc.perform(post("/api/v1/items")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(newItem)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.name").value("New Item"))
            .andExpect(jsonPath("$.description").value("New Description"));

        verify(itemRepository, times(1)).save(any(Item.class));
    }

    @Test
    void updateItem_WhenItemExists_ShouldReturnUpdatedItem() throws Exception {
        // Arrange
        Item updatedItem = new Item(1L, "Updated Item", "Updated Description");
        when(itemRepository.existsById(1L)).thenReturn(true);
        when(itemRepository.save(any(Item.class))).thenReturn(updatedItem);

        // Act & Assert
        mockMvc.perform(put("/api/v1/items/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updatedItem)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.name").value("Updated Item"))
            .andExpect(jsonPath("$.description").value("Updated Description"));

        verify(itemRepository, times(1)).existsById(1L);
        verify(itemRepository, times(1)).save(any(Item.class));
    }

    @Test
    void updateItem_WhenItemNotFound_ShouldReturn404() throws Exception {
        // Arrange
        Item updatedItem = new Item(999L, "Updated Item", "Updated Description");
        when(itemRepository.existsById(999L)).thenReturn(false);

        // Act & Assert
        mockMvc.perform(put("/api/v1/items/999")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updatedItem)))
            .andExpect(status().isNotFound());

        verify(itemRepository, times(1)).existsById(999L);
        verify(itemRepository, never()).save(any(Item.class));
    }

    @Test
    void deleteItem_WhenItemExists_ShouldReturn204() throws Exception {
        // Arrange
        when(itemRepository.existsById(1L)).thenReturn(true);
        doNothing().when(itemRepository).deleteById(1L);

        // Act & Assert
        mockMvc.perform(delete("/api/v1/items/1"))
            .andExpect(status().isNoContent());

        verify(itemRepository, times(1)).existsById(1L);
        verify(itemRepository, times(1)).deleteById(1L);
    }

    @Test
    void deleteItem_WhenItemNotFound_ShouldReturn404() throws Exception {
        // Arrange
        when(itemRepository.existsById(999L)).thenReturn(false);

        // Act & Assert
        mockMvc.perform(delete("/api/v1/items/999"))
            .andExpect(status().isNotFound());

        verify(itemRepository, times(1)).existsById(999L);
        verify(itemRepository, never()).deleteById(anyLong());
    }
}
