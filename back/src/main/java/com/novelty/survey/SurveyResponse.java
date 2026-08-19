package com.novelty.survey;

public record SurveyResponse(long surveyId, String status) {

	public static SurveyResponse saved(long surveyId) {
		return new SurveyResponse(surveyId, "SAVED");
	}
}
