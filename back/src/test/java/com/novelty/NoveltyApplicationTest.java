package com.novelty;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.NONE,
        properties = {
                "spring.datasource.url=jdbc:oracle:thin:@localhost:1521:XE",
                "spring.datasource.username=context-test",
                "spring.datasource.password=context-test"
        })
class NoveltyApplicationTest {

    @Test
    void loadsApplicationContext() {
    }
}
