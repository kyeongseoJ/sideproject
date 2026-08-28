package com.novelty.config;

import java.util.Arrays;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

@Configuration
public class ApiCorsConfig {

    @Bean
    ApiCacheControlFilter apiCacheControlFilter() {
        return new ApiCacheControlFilter();
    }

    @Bean
    CorsFilter apiCorsFilter(
            @Value("${novelty.cors.allowed-origin-patterns}") String allowedOriginPatterns) {
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", apiCorsConfiguration(allowedOriginPatterns));
        return new CorsFilter(source);
    }

    static CorsConfiguration apiCorsConfiguration(String allowedOriginPatterns) {
        List<String> patterns = Arrays.stream(allowedOriginPatterns.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .toList();
        if (patterns.isEmpty()) {
            throw new IllegalStateException("At least one API CORS origin pattern is required.");
        }

        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(patterns);
        configuration.setAllowedMethods(List.of("GET", "POST", "PATCH", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("Accept", "Content-Type", "X-User-Key"));
        configuration.setMaxAge(3600L);
        return configuration;
    }
}
