package com.novelty.user;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

@Component
public class NicknameBannedWords {

    static final String RESOURCE_PATH = "config/nickname_banned_words.txt";
    private static final Pattern WORD_PATTERN = Pattern.compile("^[가-힣A-Z0-9]{1,36}$");

    private final Set<String> normalizedWords;

    public NicknameBannedWords() {
        this.normalizedWords = loadResource();
    }

    public boolean contains(String normalizedNickname) {
        return normalizedWords.stream().anyMatch(normalizedNickname::contains);
    }

    int size() {
        return normalizedWords.size();
    }

    static Set<String> parse(String contents) {
        Set<String> words = new LinkedHashSet<>();
        for (String line : contents.lines().toList()) {
            String word = line.trim();
            if (word.isEmpty() || word.startsWith("#")) {
                continue;
            }

            String normalizedWord = Normalizer.normalize(word, Normalizer.Form.NFC)
                    .toUpperCase(Locale.ROOT);
            if (!WORD_PATTERN.matcher(normalizedWord).matches()) {
                throw new IllegalStateException("Nickname banned-word file contains an invalid entry.");
            }
            words.add(normalizedWord);
        }

        if (words.isEmpty()) {
            throw new IllegalStateException("Nickname banned-word file must not be empty.");
        }
        return Collections.unmodifiableSet(words);
    }

    private Set<String> loadResource() {
        ClassPathResource resource = new ClassPathResource(RESOURCE_PATH);
        try (var inputStream = resource.getInputStream()) {
            return parse(new String(inputStream.readAllBytes(), StandardCharsets.UTF_8));
        } catch (IOException exception) {
            throw new IllegalStateException("Nickname banned-word file could not be loaded.", exception);
        }
    }
}
