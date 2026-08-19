package com.novelty.user;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Set;

import org.junit.jupiter.api.Test;

class NicknameBannedWordsTest {

    @Test
    void loadsSharedClasspathFile() {
        NicknameBannedWords bannedWords = new NicknameBannedWords();

        assertEquals(9, bannedWords.size());
    }

    @Test
    void normalizesWordsAndSkipsComments() {
        Set<String> words = NicknameBannedWords.parse("""
                # test list
                blocked
                차단단어
                """);

        assertEquals(Set.of("BLOCKED", "차단단어"), words);
        assertTrue(words.contains("BLOCKED"));
    }

    @Test
    void rejectsEmptyOrInvalidList() {
        assertThrows(IllegalStateException.class, () -> NicknameBannedWords.parse("# comments only"));
        assertThrows(IllegalStateException.class, () -> NicknameBannedWords.parse("invalid word"));
    }
}
