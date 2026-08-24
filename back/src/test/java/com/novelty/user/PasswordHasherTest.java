package com.novelty.user;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PasswordHasherTest {

    private final PasswordHasher hasher = new PasswordHasher();

    @Test
    void hashesWithRandomSaltAndVerifiesWithoutStoringPlainText() {
        String first = hasher.hash("Password1");
        String second = hasher.hash("Password1");

        assertNotEquals(first, second);
        assertFalse(first.contains("Password1"));
        assertTrue(hasher.matches("Password1", first));
        assertFalse(hasher.matches("Wrong123", first));
        assertFalse(hasher.matches("Password1", "malformed"));
    }
}
