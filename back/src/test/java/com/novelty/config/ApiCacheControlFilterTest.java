package com.novelty.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

class ApiCacheControlFilterTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new ApiProbeController())
                .addFilters(new ApiCacheControlFilter())
                .build();
    }

    @Test
    void preventsCachingForApiResponses() throws Exception {
        mockMvc.perform(get("/api/probe").header("X-User-Key", "user-a"))
                .andExpect(status().isOk())
                .andExpect(header().string(
                        "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"))
                .andExpect(header().string("Pragma", "no-cache"))
                .andExpect(header().string("Vary", "X-User-Key"));
    }

    @Test
    void doesNotChangeNonApiResponses() throws Exception {
        mockMvc.perform(get("/health-probe"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Cache-Control"));
    }

    @RestController
    @RequestMapping
    static class ApiProbeController {
        @GetMapping("/api/probe")
        String apiProbe() {
            return "ok";
        }

        @GetMapping("/health-probe")
        String healthProbe() {
            return "ok";
        }
    }
}
