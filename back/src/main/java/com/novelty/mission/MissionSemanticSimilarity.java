package com.novelty.mission;

import java.util.OptionalDouble;

/** Extension point for a future embedding provider. */
public interface MissionSemanticSimilarity {

    OptionalDouble similarity(Mission left, Mission right);
}
