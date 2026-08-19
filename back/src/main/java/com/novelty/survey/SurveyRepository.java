package com.novelty.survey;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SurveyRepository {

	private static final String NEXT_SURVEY_ID_SQL =
			"SELECT SURVEY_RESPONSE_SEQ.NEXTVAL FROM DUAL";

	private static final String INSERT_SURVEY_SQL = """
			INSERT INTO SURVEY_RESPONSE (
				SURVEY_ID,
				ACTIVITY_LEVEL,
				SOCIAL_ACTIVITY,
				NOVELTY_TOLERANCE,
				ENERGY_LEVEL
			) VALUES (?, ?, ?, ?, ?)
			""";

	private static final String INSERT_INTEREST_SQL = """
			INSERT INTO SURVEY_INTEREST (SURVEY_ID, INTEREST_CODE)
			VALUES (?, ?)
			""";

	private final JdbcTemplate jdbcTemplate;

	public SurveyRepository(JdbcTemplate jdbcTemplate) {
		this.jdbcTemplate = jdbcTemplate;
	}

	public long save(SurveyRequest request) {
		Long surveyId = jdbcTemplate.queryForObject(NEXT_SURVEY_ID_SQL, Long.class);
		if (surveyId == null) {
			throw new IllegalStateException("Oracle did not return a survey ID.");
		}

		jdbcTemplate.update(
				INSERT_SURVEY_SQL,
				surveyId,
				request.activityLevel().name(),
				request.socialActivity().name(),
				request.noveltyTolerance().name(),
				request.energyLevel().name());

		List<Object[]> interestParameters = request.interests().stream()
				.map(interest -> new Object[] {surveyId, interest.name()})
				.toList();
		jdbcTemplate.batchUpdate(INSERT_INTEREST_SQL, interestParameters);

		return surveyId;
	}
}
