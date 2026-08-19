package com.novelty.config;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.ZoneId;
import java.util.TimeZone;

import org.junit.jupiter.api.Test;

class ServiceTimeConfigTest {

    @Test
    void usesAsiaSeoulAsServiceTimezone() {
        ServiceTimeConfig config = new ServiceTimeConfig();
        Clock clock = config.serviceClock();

        assertEquals(ZoneId.of("Asia/Seoul"), clock.getZone());
        assertEquals("Asia/Seoul", TimeZone.getDefault().getID());
    }
}
