package com.novelty;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.NONE,
        properties = {
                "spring.datasource.url=${DB_URL:jdbc:postgresql://localhost:5432/postgres}",
                "spring.datasource.username=${DB_USERNAME:test}",
                "spring.datasource.password=${DB_PASSWORD:test}"
        })
class NoveltyApplicationTest {

    @Test
    void loadsApplicationContext() {
    }
}
