package com.novelty.survey;

import java.util.List;

public record SurveyRequest(
		ActivityLevel activityLevel,
		SocialActivity socialActivity,
		NoveltyTolerance noveltyTolerance,
		List<Interest> interests,
		EnergyLevel energyLevel) {

	public SurveyRequest {
		interests = interests == null ? null : List.copyOf(interests);
	}

	public enum ActivityLevel {
		INDOOR,
		MIXED,
		OUTDOOR
	}

	public enum SocialActivity {
		LOW,
		MEDIUM,
		HIGH
	}

	public enum NoveltyTolerance {
		LOW,
		MEDIUM,
		HIGH
	}

	public enum Interest {
		MOVEMENT,
		CREATIVE,
		FOOD,
		LEARNING,
		SOCIAL,
		OUTDOOR,
		ORGANIZING,
		CULTURE
	}

	public enum EnergyLevel {
		LOW,
		MEDIUM,
		HIGH
	}
}
