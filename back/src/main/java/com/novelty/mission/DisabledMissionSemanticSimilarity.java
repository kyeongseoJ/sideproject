package com.novelty.mission;

import java.util.OptionalDouble;

import org.springframework.stereotype.Component;

@Component
public class DisabledMissionSemanticSimilarity implements MissionSemanticSimilarity {

    @Override
    public OptionalDouble similarity(Mission left, Mission right) {
        return OptionalDouble.empty();
    }
}
