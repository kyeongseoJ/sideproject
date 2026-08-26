package com.novelty.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;

@Configuration
public class OpenApiConfig {

    @Bean
    OpenAPI noveltyOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Novelty API")
                        .description("노벨티 프로젝트 REST API")
                        .version("v1"));
    }
}
