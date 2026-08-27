package com.novelty.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.web.cors.CorsConfiguration;

class ApiCorsConfigTest {

    @Test
    void allowsConfiguredProductionAndLocalOrigins() {
        CorsConfiguration configuration = ApiCorsConfig.apiCorsConfiguration(
                "https://app.novelty.example, http://localhost:*, http://127.0.0.1:*");

        assertEquals("https://app.novelty.example",
                configuration.checkOrigin("https://app.novelty.example"));
        assertEquals("http://localhost:3000", configuration.checkOrigin("http://localhost:3000"));
        assertNull(configuration.checkOrigin("https://untrusted.example"));
    }

    @Test
    void requiresAtLeastOneOriginPattern() {
        assertThrows(IllegalStateException.class,
                () -> ApiCorsConfig.apiCorsConfiguration(" , "));
    }
}
