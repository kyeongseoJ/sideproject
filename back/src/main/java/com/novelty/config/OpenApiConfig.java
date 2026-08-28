package com.novelty.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;

import java.util.List;
import io.swagger.v3.oas.models.servers.Server;

@Configuration
public class OpenApiConfig {

    @Bean
    OpenAPI noveltyOpenApi() {
        return new OpenAPI()
                .servers(List.of(
                        new Server()
                                .url("https://kyeongseoj-api.dx6project.site")
                                .description("Production API")
                ))
                .info(new Info()
                        .title("Novelty API")
                        .description("Novelty 프로젝트 REST API")
                        .version("v1"));
    }
}
