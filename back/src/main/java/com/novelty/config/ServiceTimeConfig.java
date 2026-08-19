package com.novelty.config;

import java.time.Clock;
import java.time.ZoneId;
import java.util.TimeZone;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ServiceTimeConfig {

    public static final ZoneId SERVICE_ZONE = ZoneId.of("Asia/Seoul");

    public ServiceTimeConfig() {
        TimeZone.setDefault(TimeZone.getTimeZone(SERVICE_ZONE));
    }

    @Bean
    public Clock serviceClock() {
        return Clock.system(SERVICE_ZONE);
    }
}
